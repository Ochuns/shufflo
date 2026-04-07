-- ==========================================
-- 【決定版】権限・論理削除・履歴管理の統合SQL
-- ==========================================

-- 1. すべてのテーブルの RLS を有効化
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- 2. 閲覧(SELECT)ポリシーの修正
-- 公開カード・ポストは「削除されていないもの」または「本人のもの」が見えるようにする
DROP POLICY IF EXISTS "Anyone can see active posts" ON posts;
CREATE POLICY "Anyone can see active posts" ON posts
  FOR SELECT USING (deleted_at IS NULL OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can see active public cards" ON public_cards;
CREATE POLICY "Anyone can see active public cards" ON public_cards
  FOR SELECT USING (deleted_at IS NULL OR auth.uid() = user_id);

-- プライベートカードは「常に本人のもの」が見えるようにする
DROP POLICY IF EXISTS "Users can see their own active private cards" ON private_cards;
CREATE POLICY "Users can see their own active private cards" ON private_cards
  FOR SELECT USING (auth.uid() = user_id);


-- 2. 新規作成(INSERT)ポリシーの追加
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
CREATE POLICY "Users can insert their own posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own public cards" ON public_cards;
CREATE POLICY "Users can insert their own public cards" ON public_cards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own private cards" ON private_cards;
CREATE POLICY "Users can insert their own private cards" ON private_cards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- location は場所登録のために誰でもINSERT/SELECT可にする
DROP POLICY IF EXISTS "Anyone can manage locations" ON locations;
CREATE POLICY "Anyone can manage locations" ON locations
  FOR ALL USING (true);


-- 3. 更新(UPDATE)ポリシーの修正
-- 削除フラグの操作を含め、本人は自由に更新できるようにする
DROP POLICY IF EXISTS "Users can manage their own posts" ON posts;
CREATE POLICY "Users can manage their own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own public cards" ON public_cards;
CREATE POLICY "Users can update their own public cards" ON public_cards
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own private cards" ON private_cards;
CREATE POLICY "Users can update their own private cards" ON private_cards
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
