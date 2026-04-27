-- ==========================================
-- Shufflo Database Update: Decks & Rarity
-- ==========================================

-- 1. デッキ（アルバム）テーブルの作成
CREATE TABLE decks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS（権限管理）の設定
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own decks" ON decks
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. 既存のカードテーブルに「所属するデッキ（Deck ID）」を追加
-- これで個々のカードを特定のデッキにまとめることができます
ALTER TABLE public_cards ADD COLUMN deck_id UUID REFERENCES decks(id) ON DELETE SET NULL;
ALTER TABLE private_cards ADD COLUMN deck_id UUID REFERENCES decks(id) ON DELETE SET NULL;

-- 3. レアリティ（Rarity）カラムの追加
-- 投稿の少なさやアルゴリズムで決定するレアリティの保管場所
-- 'common', 'rare', 'epic', 'legendary' などの文字列を保存します
ALTER TABLE posts ADD COLUMN rarity TEXT DEFAULT 'common';
ALTER TABLE public_cards ADD COLUMN rarity TEXT DEFAULT 'common';

-- (参考) Row Level Security (RLS) をオフにする場合（MVPテスト用）
-- ALTER TABLE decks DISABLE ROW LEVEL SECURITY;

-- ==========================================
-- Shufflo Database Update: Local Fast Display & Storage
-- ==========================================

-- 4. Storage バケット 'card-images' の作成
INSERT INTO storage.buckets (id, name, public) 
VALUES ('card-images', 'card-images', true)
ON CONFLICT (id) DO NOTHING;

-- 5. Storage のポリシー設定
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'card-images');
CREATE POLICY "Authenticated User Insert" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'card-images'
        AND auth.role() = 'authenticated'
        AND name LIKE auth.uid()::text || '/%'
    );

-- 6. DBテーブルにローカル保存用の local_image_path カラムを追加
ALTER TABLE public_cards ADD COLUMN IF NOT EXISTS local_image_path TEXT;
ALTER TABLE private_cards ADD COLUMN IF NOT EXISTS local_image_path TEXT;

-- ==========================================
-- Shufflo Database Update: Spatial Query RPC
-- ==========================================

-- PostGIS の空間関数（ST_DWithin / ST_Distance / geography 変換）を使うために有効化
CREATE EXTENSION IF NOT EXISTS postgis;

-- 空間検索を高速化するための GiST インデックスを作成
CREATE INDEX IF NOT EXISTS public_cards_location_idx ON public_cards USING GIST (location_coords);
CREATE INDEX IF NOT EXISTS private_cards_location_idx ON private_cards USING GIST (location_coords);
-- 近くのカードをPostGISの機能で検索し、近い順に返す関数
CREATE OR REPLACE FUNCTION get_nearby_public_cards(
  target_lat float,
  target_lon float,
  max_dist_meters float,
  limit_num int
) RETURNS SETOF public_cards AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public_cards
  WHERE deleted_at IS NULL
    -- ST_DWithin で指定範囲内かどうかをインデックスを使って高速判定
    AND ST_DWithin(
          location_coords::geography,
          ST_Point(target_lon, target_lat)::geography,
          max_dist_meters
        )
  -- ST_Distance で距離順にソート
  ORDER BY ST_Distance(
             location_coords::geography,
             ST_Point(target_lon, target_lat)::geography
           ) ASC
  LIMIT limit_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- ==========================================
-- Shufflo Database Update: Logical Delete Permissions
-- ==========================================

-- カード（Post）の論理削除を許可するポリシーの強化
DROP POLICY IF EXISTS "Users can manage their own posts" ON posts;
CREATE POLICY "Users can manage their own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own public cards" ON public_cards;
CREATE POLICY "Users can update their own public cards" ON public_cards
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own private cards" ON private_cards;
CREATE POLICY "Users can update their own private cards" ON private_cards
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 閲覧ポリシーの微調整（削除済みでも本人なら見れるようにする）
DROP POLICY IF EXISTS "Anyone can see active posts" ON posts;
CREATE POLICY "Anyone can see active posts" ON posts
  FOR SELECT USING (deleted_at IS NULL OR auth.uid() = user_id);
