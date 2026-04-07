-- ==========================================
-- 【初期スキーマ】Shufflo 基本テーブル定義
-- ==========================================

-- 0. 拡張機能の有効化 (位置情報用)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. ユーザーテーブル
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  username TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 場所テーブル
CREATE TABLE IF NOT EXISTS locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ポスト(投稿の核)テーブル
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  location_id UUID REFERENCES locations(id),
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  rating INTEGER DEFAULT 3,
  comment TEXT,
  public_image_url TEXT,
  private_image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 公開カードテーブル (探索用)
CREATE TABLE IF NOT EXISTS public_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id),
  user_id UUID REFERENCES users(id),
  location_id UUID REFERENCES locations(id),
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  rating INTEGER,
  comment TEXT,
  image_url TEXT,
  location_coords GEOGRAPHY(POINT) NOT NULL, -- マップ検索用
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. プライベートカードテーブル (コレクション用)
CREATE TABLE IF NOT EXISTS private_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id),
  user_id UUID REFERENCES users(id),
  location_id UUID REFERENCES locations(id),
  comment TEXT,
  image_url TEXT,
  visited_date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. インデックス (検索高速化)
CREATE INDEX IF NOT EXISTS idx_public_cards_coords ON public_cards USING GIST(location_coords);
CREATE INDEX IF NOT EXISTS idx_private_cards_user ON private_cards(user_id);
