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

-- 5. Storage のポリシー設定（誰でもアップロード・閲覧可能にする：MVP設定）
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'card-images');
CREATE POLICY "Public Insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'card-images');

-- 6. DBテーブルにローカル保存用の local_image_path カラムを追加
ALTER TABLE public_cards ADD COLUMN IF NOT EXISTS local_image_path TEXT;
ALTER TABLE private_cards ADD COLUMN IF NOT EXISTS local_image_path TEXT;
