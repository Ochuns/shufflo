-- ==========================================
-- リニューアル 01: プロフィール拡張 (既存 users テーブルを再利用)
--   - bio 列 (<=140)
--   - username の大小無視 UNIQUE
--   - users テーブルの RLS 有効化 (本人のみ編集可)
-- 冪等。再実行可能。
-- ==========================================

-- 1. bio 列の追加 (140文字以内)
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_bio_length_chk') THEN
    ALTER TABLE users ADD CONSTRAINT users_bio_length_chk
      CHECK (bio IS NULL OR char_length(bio) <= 140);
  END IF;
END $$;

-- 2. username の大小無視 UNIQUE
--    既存データに大小無視の重複があるとインデックス作成が失敗する。
--    データ破壊を避けるため、重複があれば明示的に中断して手動対応を促す。
DO $$
DECLARE
  dup_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO dup_count FROM (
    SELECT lower(username) FROM users GROUP BY lower(username) HAVING COUNT(*) > 1
  ) d;
  IF dup_count > 0 THEN
    RAISE EXCEPTION 'username に大小無視で重複が % 種類あります。重複を解消してから再実行してください（中断）。', dup_count;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_unique ON users (lower(username));

-- 3. RLS 有効化
--    現状 users は RLS 未設定 = 誰でも他人のプロフィールを更新できる状態。
--    本人のみ編集可に是正する (仕様15)。
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- SELECT: username/avatar/bio は公開プロフィール情報。全員閲覧可。
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone" ON users
  FOR SELECT USING (true);

-- INSERT: 本人の行のみ
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- UPDATE: 本人の行のみ (id は不変)
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- DELETE ポリシーは作成しない。
-- アカウント削除は Edge Function (service role) 経由でのみ行い、
-- users 行削除 -> 各個人データ ON DELETE CASCADE で一括削除する。
