-- ==========================================
-- リニューアル 09: 認証プロフィールのブートストラップ
--   - is_username_available(): 登録前のユーザー名重複チェック(UX用)
--   - handle_new_user(): auth.users 作成時に public.users を自動生成
--       (username はメタデータから。無ければ衝突しないデフォルトを付与)
-- 依存: 01(users, username大小無視UNIQUE)
-- 冪等。再実行可能。
-- ==========================================

-- ------------------------------------------
-- ユーザー名の可用性チェック (大小無視)
--   登録前に呼ぶUX用。確定的な一意性は users の UNIQUE インデックスで担保。
-- ------------------------------------------
CREATE OR REPLACE FUNCTION is_username_available(p_username TEXT)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM users WHERE lower(username) = lower(trim(p_username))
  );
$$;
GRANT EXECUTE ON FUNCTION is_username_available(TEXT) TO anon, authenticated;

-- ------------------------------------------
-- auth.users 作成時に public.users 行を自動生成
--   - username: raw_user_meta_data->>'username' を使用
--   - 無い場合 (匿名ログイン等) は衝突しないデフォルト 'user_<uid8>' を付与
--     => 既存 _ensureUserExists の 'Anonymous Explorer' 重複衝突を回避
--   - username がユーザー指定で既存と重複する場合は UNIQUE 違反となり
--     サインアップ自体が失敗する (= サーバー側での一意性強制)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_username TEXT;
BEGIN
  v_username := NULLIF(trim(NEW.raw_user_meta_data->>'username'), '');
  IF v_username IS NULL THEN
    v_username := 'user_' || substr(replace(NEW.id::text, '-', ''), 1, 8);
  END IF;

  INSERT INTO public.users (id, username)
  VALUES (NEW.id, v_username)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_handle_new_user ON auth.users;
CREATE TRIGGER tr_handle_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
