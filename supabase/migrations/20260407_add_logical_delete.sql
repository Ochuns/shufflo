-- 1. 各テーブルに deleted_at カラムを追加
ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public_cards ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE private_cards ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. 既存のビューや RLS ポリシーがある場合は、それらが deleted_at IS NULL を考慮するように修正
-- (MVP構成のため、SELECTのフィルタリングはアプリ側クエリで行います)

-- 3. RLS ポリシーの強化 (自分以外のユーザーが物理削除・更新できないように制限)
-- すべてのテーブルに対して、更新・削除は所有者のみとするポリシー (既に存在する場合はスキップ)

-- 3a. posts テーブル用
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'posts' AND policyname = 'Users can update their own posts') THEN
    CREATE POLICY "Users can update their own posts" ON posts
      FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- 4. 開発・テスト用にインデックスを追加 (クエリ高速化)
CREATE INDEX IF NOT EXISTS idx_posts_deleted_at ON posts (deleted_at);
CREATE INDEX IF NOT EXISTS idx_public_cards_deleted_at ON public_cards (deleted_at);
CREATE INDEX IF NOT EXISTS idx_private_cards_deleted_at ON private_cards (deleted_at);

-- 6. 秘策：部分インデックス (Partial Index) の作成 【負荷対策の要】
-- 「削除されていないデータだけ」をインデックス化するため、検索が常に高速です。
-- これにより、削除済みデータがどれだけ増えても、アクティブなデータの検索速度に影響しません。
CREATE INDEX IF NOT EXISTS idx_active_posts 
  ON posts (user_id, created_at) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_active_public_cards 
  ON public_cards (id, created_at) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_active_private_cards 
  ON private_cards (user_id, visited_date) 
  WHERE deleted_at IS NULL;

-- 7. 効率化：アクティブ・ビュー (View) の作成 【開発の簡略化】
-- これを使えば、アプリ側は毎回 WHERE deleted_at IS NULL と書く手間が省けます。
-- 今後アプリが大きくなった際に「削除済みカードをうっかり表示してしまう」ミスを防げます。

CREATE OR REPLACE VIEW active_public_cards AS
  SELECT * FROM public_cards WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW active_private_cards AS
  SELECT * FROM private_cards WHERE deleted_at IS NULL;

-- 8. 安全：RLS ポリシーの強化
-- 自分でない人がデータを「削除済み(UPDATE)」にしたり、
-- 削除済みのデータを他人が「閲覧(SELECT)」したりできないようにします。
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 参照は「削除されていないもの」限定にするポリシー例
DROP POLICY IF EXISTS "Anyone can see active posts" ON posts;
CREATE POLICY "Anyone can see active posts" ON posts
  FOR SELECT USING (deleted_at IS NULL);

-- 更新（論理削除含む）は本人限定
DROP POLICY IF EXISTS "Users can manage their own posts" ON posts;
CREATE POLICY "Users can manage their own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
