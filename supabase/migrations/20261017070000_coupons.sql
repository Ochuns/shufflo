-- ==========================================
-- リニューアル 07: クーポン
--   - coupons (user×theme×cycle で一意 / 冪等キー / 30日有効)
--   - claim_theme_reward() : サイクル完成を検証し冪等に発行、成功時に次サイクルへ
--   - use_coupon()        : active かつ未期限のみ used に。二重使用防止。
-- 依存: 05(themes), 06(theme_cycles, theme_progress, get_current_cycle)
-- 冪等。再実行可能。
-- ==========================================

CREATE TABLE IF NOT EXISTS coupons (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id           UUID NOT NULL REFERENCES themes(id),
  cycle_number       INTEGER NOT NULL,
  reward_title       TEXT,
  reward_description TEXT,
  status             TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','used','expired')),
  issued_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at         TIMESTAMPTZ NOT NULL,
  used_at            TIMESTAMPTZ,
  idempotency_key    TEXT NOT NULL,
  CONSTRAINT coupons_unique_cycle UNIQUE (user_id, theme_id, cycle_number),
  CONSTRAINT coupons_idempotency_unique UNIQUE (idempotency_key)
);
CREATE INDEX IF NOT EXISTS coupons_user_idx ON coupons (user_id, status);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
-- SELECT: 本人のみ (他人のクーポンは見えない)
DROP POLICY IF EXISTS "View own coupons" ON coupons;
CREATE POLICY "View own coupons" ON coupons
  FOR SELECT USING (user_id = auth.uid());
-- INSERT/UPDATE は関数経由のみ

-- ------------------------------------------
-- claim_theme_reward: 報酬受け取り
--   現在サイクルが完成 (全対象店舗スロット充足) かを検証して冪等に発行。
--   二重タップ/再試行では既存クーポンを返す (重複発行しない)。
--   発行成功時に当該テーマの現在サイクルを +1 (進捗行は履歴として残す)。
-- ------------------------------------------
CREATE OR REPLACE FUNCTION claim_theme_reward(p_theme_id UUID)
RETURNS coupons
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid      UUID := auth.uid();
  v_theme    themes;
  v_cycle    INTEGER;
  v_required INTEGER;
  v_have     INTEGER;
  v_idem     TEXT;
  v_coupon   coupons;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT * INTO v_theme FROM themes WHERE id = p_theme_id AND is_active;
  IF v_theme.id IS NULL THEN RAISE EXCEPTION 'theme not found or inactive'; END IF;

  -- 現在サイクル行を確実に用意してから行ロックで同時発行を直列化する (C3対策)
  v_cycle := get_current_cycle(v_uid, p_theme_id);
  PERFORM 1 FROM theme_cycles WHERE user_id = v_uid AND theme_id = p_theme_id FOR UPDATE;
  -- ロック取得後に権威ある現在サイクルを読み直す
  SELECT cycle_number INTO v_cycle FROM theme_cycles
    WHERE user_id = v_uid AND theme_id = p_theme_id;
  v_idem  := v_uid::text || ':' || p_theme_id::text || ':' || v_cycle::text;

  -- 既に当サイクルで発行済みなら冪等に返す
  SELECT * INTO v_coupon FROM coupons WHERE idempotency_key = v_idem;
  IF v_coupon.id IS NOT NULL THEN
    RETURN v_coupon;
  END IF;

  -- 完成判定: 当サイクルの「現対象店舗」の進捗数 == 対象店舗数
  -- (後から theme_stores が編集され対象外になった店舗の進捗は数えない, M1対策)
  SELECT COUNT(*) INTO v_required FROM theme_stores WHERE theme_id = p_theme_id;
  SELECT COUNT(DISTINCT tp.store_id) INTO v_have
    FROM theme_progress tp
    JOIN theme_stores ts ON ts.theme_id = tp.theme_id AND ts.store_id = tp.store_id
    WHERE tp.user_id = v_uid AND tp.theme_id = p_theme_id AND tp.cycle_number = v_cycle;
  IF v_required = 0 OR v_have < v_required THEN
    RAISE EXCEPTION 'theme is not complete for the current cycle (% / %)', v_have, v_required;
  END IF;

  INSERT INTO coupons
    (user_id, theme_id, cycle_number, reward_title, reward_description,
     status, issued_at, expires_at, idempotency_key)
  VALUES
    (v_uid, p_theme_id, v_cycle, v_theme.reward_title, v_theme.reward_description,
     'active', now(), now() + interval '30 days', v_idem)
  ON CONFLICT (idempotency_key) DO NOTHING
  RETURNING * INTO v_coupon;

  IF v_coupon.id IS NULL THEN
    -- 競合で負けた場合は既存を返す
    SELECT * INTO v_coupon FROM coupons WHERE idempotency_key = v_idem;
    RETURN v_coupon;
  END IF;

  -- 当該テーマの進捗だけを次サイクルへ (進捗行は履歴として残す)
  UPDATE theme_cycles SET cycle_number = cycle_number + 1
    WHERE user_id = v_uid AND theme_id = p_theme_id;

  RETURN v_coupon;
END;
$$;

-- ------------------------------------------
-- use_coupon: 利用。active かつ未期限のみ used に。二重使用防止。
-- ------------------------------------------
CREATE OR REPLACE FUNCTION use_coupon(p_coupon_id UUID)
RETURNS coupons
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_c   coupons;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT * INTO v_c FROM coupons WHERE id = p_coupon_id FOR UPDATE;
  IF v_c.id IS NULL THEN RAISE EXCEPTION 'coupon not found'; END IF;
  IF v_c.user_id <> v_uid THEN RAISE EXCEPTION 'not authorized'; END IF;

  IF v_c.expires_at <= now() THEN
    UPDATE coupons SET status = 'expired' WHERE id = p_coupon_id;
    RAISE EXCEPTION 'coupon has expired';
  END IF;
  IF v_c.status <> 'active' THEN
    RAISE EXCEPTION 'coupon is not usable (status=%)', v_c.status;
  END IF;

  UPDATE coupons SET status = 'used', used_at = now()
    WHERE id = p_coupon_id
  RETURNING * INTO v_c;
  RETURN v_c;
END;
$$;

-- 実行権限
REVOKE EXECUTE ON FUNCTION claim_theme_reward(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION use_coupon(UUID)         FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION claim_theme_reward(UUID) TO authenticated;
GRANT  EXECUTE ON FUNCTION use_coupon(UUID)         TO authenticated;

-- 注: 'expired' ステータスは利用試行時に遅延設定される。
--     一覧表示では (status='active' AND expires_at <= now()) を期限切れ扱いにすること。
