-- ==========================================
-- リニューアル 05: 店舗・テーマ
--   - stores (固定ID / PostGIS位置 / is_active)
--   - store_qr_tokens (QRトークンのハッシュ。クライアント非公開: RLS有効&ポリシーなし)
--   - themes / theme_stores / theme_reward_stores
-- 依存: PostGIS (既存で有効), pgcrypto
-- 冪等。再実行可能。
-- ==========================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------
-- 店舗
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS stores (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  location   GEOGRAPHY(POINT) NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stores_location_idx ON stores USING GIST (location);

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Active stores readable" ON stores;
CREATE POLICY "Active stores readable" ON stores
  FOR SELECT USING (is_active);
-- 書き込みポリシーなし => クライアントは変更不可 (DB直/将来の管理UI/service role)

-- ------------------------------------------
-- QRトークン (店舗ごとの固定コードのハッシュ)
--   RLS 有効 + ポリシーなし => authenticated/anon からは一切読めない。
--   verify_visit() (SECURITY DEFINER) だけが照合に使う。
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS store_qr_tokens (
  store_id   UUID PRIMARY KEY REFERENCES stores(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT store_qr_tokens_hash_unique UNIQUE (token_hash)
);
ALTER TABLE store_qr_tokens ENABLE ROW LEVEL SECURITY;
-- ポリシーを一切作らない (= 完全非公開)

-- 運用補助: 平文トークンからハッシュを登録するヘルパー (DB管理者/service role 用)
--   例: SELECT set_store_qr_token('<store_uuid>', '<printed_token>');
CREATE OR REPLACE FUNCTION set_store_qr_token(p_store_id UUID, p_token TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
-- extensions も含める: Supabase では pgcrypto(digest) が extensions スキーマに入る場合がある
SET search_path = public, extensions, pg_catalog
AS $$
BEGIN
  INSERT INTO store_qr_tokens (store_id, token_hash)
  VALUES (p_store_id, encode(digest(p_token, 'sha256'), 'hex'))
  ON CONFLICT (store_id)
  DO UPDATE SET token_hash = EXCLUDED.token_hash;
END;
$$;
-- このヘルパーはクライアントから呼べないようにする (service role / DB直のみ)
REVOKE EXECUTE ON FUNCTION set_store_qr_token(UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION set_store_qr_token(UUID, TEXT) FROM anon, authenticated;

-- ------------------------------------------
-- テーマ
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS themes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  sort_order         INTEGER NOT NULL DEFAULT 0,  -- 安定した表示順
  reward_title       TEXT,
  reward_description TEXT,
  is_active          BOOLEAN NOT NULL DEFAULT true,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE themes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Active themes readable" ON themes;
CREATE POLICY "Active themes readable" ON themes
  FOR SELECT USING (is_active);

-- 対象店舗 (M:N)。対象判定は固定 store_id で行う (曖昧一致/AI推測を使わない)
CREATE TABLE IF NOT EXISTS theme_stores (
  theme_id UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  PRIMARY KEY (theme_id, store_id)
);
ALTER TABLE theme_stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Theme stores readable" ON theme_stores;
CREATE POLICY "Theme stores readable" ON theme_stores
  FOR SELECT USING (true);

-- 報酬の利用可能店舗 (M:N)
CREATE TABLE IF NOT EXISTS theme_reward_stores (
  theme_id UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  PRIMARY KEY (theme_id, store_id)
);
ALTER TABLE theme_reward_stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Theme reward stores readable" ON theme_reward_stores;
CREATE POLICY "Theme reward stores readable" ON theme_reward_stores
  FOR SELECT USING (true);
