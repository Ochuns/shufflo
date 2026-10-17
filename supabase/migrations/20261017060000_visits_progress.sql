-- ==========================================
-- リニューアル 06: 訪問確認・検証済み訪問記録・テーマ進捗
--   - visit_verifications (24h / GPS&QRをサーバー判定)
--   - visited_records (カードと分離。投稿論理削除後も維持)
--   - theme_cycles (ユーザー×テーマの現在サイクル)
--   - theme_progress (同一店舗×同一サイクルは重複カウントしない)
--   - verify_visit() / complete_theme_visit() / get_current_cycle()
-- 依存: 05(stores, store_qr_tokens, themes, theme_stores), PostGIS, pgcrypto
-- 冪等。再実行可能。
-- ==========================================

-- ------------------------------------------
-- 訪問確認状態 (24時間有効)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS visit_verifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id     UUID NOT NULL REFERENCES stores(id),
  gps_verified BOOLEAN NOT NULL DEFAULT false,
  qr_verified  BOOLEAN NOT NULL DEFAULT false,
  verified_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL,
  consumed     BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS visit_verifications_user_idx
  ON visit_verifications (user_id, store_id, consumed, expires_at);

ALTER TABLE visit_verifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View own verifications" ON visit_verifications;
CREATE POLICY "View own verifications" ON visit_verifications
  FOR SELECT USING (user_id = auth.uid());
-- 書き込みは関数経由のみ

-- ------------------------------------------
-- 検証済み訪問記録 (カード投稿とは分離)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS visited_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id        UUID NOT NULL REFERENCES stores(id),
  post_id         UUID REFERENCES posts(id) ON DELETE SET NULL,  -- 論理削除では残る。物理削除時のみNULL化
  verification_id UUID REFERENCES visit_verifications(id),
  visited_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS visited_records_user_idx ON visited_records (user_id, store_id);

ALTER TABLE visited_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View own visited records" ON visited_records;
CREATE POLICY "View own visited records" ON visited_records
  FOR SELECT USING (user_id = auth.uid());

-- ------------------------------------------
-- サイクル管理 (ユーザー×テーマ)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS theme_cycles (
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id     UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  cycle_number INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, theme_id)
);
ALTER TABLE theme_cycles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View own theme cycles" ON theme_cycles;
CREATE POLICY "View own theme cycles" ON theme_cycles
  FOR SELECT USING (user_id = auth.uid());

-- ------------------------------------------
-- テーマ進捗 (同一店舗×同一サイクルは1回だけ)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS theme_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id          UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  cycle_number      INTEGER NOT NULL,
  store_id          UUID NOT NULL REFERENCES stores(id),
  visited_record_id UUID REFERENCES visited_records(id),
  earned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT theme_progress_unique UNIQUE (user_id, theme_id, cycle_number, store_id)
);
CREATE INDEX IF NOT EXISTS theme_progress_user_theme_idx
  ON theme_progress (user_id, theme_id, cycle_number);

ALTER TABLE theme_progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View own theme progress" ON theme_progress;
CREATE POLICY "View own theme progress" ON theme_progress
  FOR SELECT USING (user_id = auth.uid());

-- ------------------------------------------
-- 現在サイクル取得 (なければ 1 で初期化)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION get_current_cycle(p_user UUID, p_theme UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_cycle INTEGER;
BEGIN
  SELECT cycle_number INTO v_cycle FROM theme_cycles
    WHERE user_id = p_user AND theme_id = p_theme;
  IF v_cycle IS NULL THEN
    INSERT INTO theme_cycles (user_id, theme_id, cycle_number)
    VALUES (p_user, p_theme, 1)
    ON CONFLICT (user_id, theme_id) DO NOTHING;
    SELECT cycle_number INTO v_cycle FROM theme_cycles
      WHERE user_id = p_user AND theme_id = p_theme;
  END IF;
  RETURN v_cycle;
END;
$$;

-- ------------------------------------------
-- verify_visit: GPS(<=100m, サーバー計算) と QR(ハッシュ照合) 双方成立で確認状態を発行
--   クライアントの距離判定結果は信用しない。期限 24h。重複は既存の有効確認を再利用。
-- ------------------------------------------
CREATE OR REPLACE FUNCTION verify_visit(p_store_id UUID, p_lat float, p_lon float, p_qr_token TEXT)
RETURNS visit_verifications
LANGUAGE plpgsql
SECURITY DEFINER
-- extensions も含める: Supabase では pgcrypto(digest) が extensions スキーマに入る場合がある
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_uid         UUID := auth.uid();
  v_store       stores;
  v_hash        TEXT;
  v_token_store UUID;
  v_recent      INTEGER;
  v_row         visit_verifications;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  -- 既存の有効・未消費の確認があれば、再スキャン不要で即返す (正当な中断/再開/リトライ)。
  -- レート制限より前に行い、正当なリトライがレート制限に当たらないようにする (M2対策)。
  SELECT * INTO v_row FROM visit_verifications
    WHERE user_id = v_uid AND store_id = p_store_id
      AND consumed = false AND expires_at > now()
    ORDER BY verified_at DESC LIMIT 1;
  IF v_row.id IS NOT NULL THEN
    RETURN v_row;
  END IF;

  SELECT * INTO v_store FROM stores WHERE id = p_store_id AND is_active;
  IF v_store.id IS NULL THEN RAISE EXCEPTION 'store not found or inactive'; END IF;

  -- レート制限: 新規確認の作成は直近5秒に1回まで
  SELECT COUNT(*) INTO v_recent FROM visit_verifications
    WHERE user_id = v_uid AND created_at > now() - interval '5 seconds';
  IF v_recent > 0 THEN RAISE EXCEPTION 'rate limit: please slow down'; END IF;

  -- QR: 受領トークンをハッシュして店舗IDを解決し、対象店舗と一致するか
  v_hash := encode(digest(p_qr_token, 'sha256'), 'hex');
  SELECT store_id INTO v_token_store FROM store_qr_tokens WHERE token_hash = v_hash;
  IF v_token_store IS NULL OR v_token_store <> p_store_id THEN
    RAISE EXCEPTION 'QR verification failed';
  END IF;

  -- GPS: サーバー側で 100m 以内か判定
  IF NOT ST_DWithin(v_store.location, ST_Point(p_lon, p_lat)::geography, 100) THEN
    RAISE EXCEPTION 'GPS verification failed (too far from the store)';
  END IF;

  INSERT INTO visit_verifications
    (user_id, store_id, gps_verified, qr_verified, verified_at, expires_at)
  VALUES
    (v_uid, p_store_id, true, true, now(), now() + interval '24 hours')
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

-- ------------------------------------------
-- complete_theme_visit: カード保存成功後に呼ぶ。
--   有効な確認を消費し、訪問記録を作成し、該当する全テーマの現在サイクルに進捗を付与。
-- ------------------------------------------
CREATE OR REPLACE FUNCTION complete_theme_visit(p_verification_id UUID, p_post_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid      UUID := auth.uid();
  v_ver      visit_verifications;
  v_record_id UUID;
  v_theme    RECORD;
  v_cycle    INTEGER;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT * INTO v_ver FROM visit_verifications WHERE id = p_verification_id FOR UPDATE;
  IF v_ver.id IS NULL THEN RAISE EXCEPTION 'verification not found'; END IF;
  IF v_ver.user_id <> v_uid THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_ver.consumed THEN RAISE EXCEPTION 'verification already consumed'; END IF;
  IF v_ver.expires_at <= now() THEN RAISE EXCEPTION 'verification expired'; END IF;
  IF NOT (v_ver.gps_verified AND v_ver.qr_verified) THEN
    RAISE EXCEPTION 'verification is incomplete';
  END IF;

  -- 対象 post が本人のものとして存在すること (= カード保存済み)
  IF NOT EXISTS (SELECT 1 FROM posts WHERE id = p_post_id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'post not found for this user';
  END IF;

  INSERT INTO visited_records (user_id, store_id, post_id, verification_id, visited_at)
  VALUES (v_uid, v_ver.store_id, p_post_id, v_ver.id, v_ver.verified_at)
  RETURNING id INTO v_record_id;

  UPDATE visit_verifications SET consumed = true WHERE id = v_ver.id;

  -- この店舗を含む有効な全テーマの現在サイクルに1スロット付与
  FOR v_theme IN
    SELECT t.id AS theme_id
    FROM themes t
    JOIN theme_stores ts ON ts.theme_id = t.id
    WHERE ts.store_id = v_ver.store_id AND t.is_active
  LOOP
    v_cycle := get_current_cycle(v_uid, v_theme.theme_id);
    INSERT INTO theme_progress (user_id, theme_id, cycle_number, store_id, visited_record_id)
    VALUES (v_uid, v_theme.theme_id, v_cycle, v_ver.store_id, v_record_id)
    ON CONFLICT (user_id, theme_id, cycle_number, store_id) DO NOTHING;
  END LOOP;
END;
$$;

-- 実行権限
REVOKE EXECUTE ON FUNCTION verify_visit(UUID, float, float, TEXT)       FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION complete_theme_visit(UUID, UUID)             FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION get_current_cycle(UUID, UUID)                FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION verify_visit(UUID, float, float, TEXT)       TO authenticated;
GRANT  EXECUTE ON FUNCTION complete_theme_visit(UUID, UUID)             TO authenticated;
GRANT  EXECUTE ON FUNCTION get_current_cycle(UUID, UUID)                TO authenticated;
