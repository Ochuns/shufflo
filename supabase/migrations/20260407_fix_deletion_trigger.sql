-- ==========================================
-- 削除機能の不具合修正：自動連動トリガーとRLSの強化
-- ==========================================

-- 1. 権限設定：public_cards と private_cards を本人が更新できるようにする
-- これがないと、アプリからの logical delete (deleted_at の更新) がブロックされます。

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'public_cards' AND policyname = 'Users can update their own public cards') THEN
    CREATE POLICY "Users can update their own public cards" ON public_cards
      FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'private_cards' AND policyname = 'Users can update their own private cards') THEN
    CREATE POLICY "Users can update their own private cards" ON private_cards
      FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- 2. 連動削除トリガーの作成
-- posts テーブルの deleted_at が更新されたら、自動的に子テーブルも更新する関数

CREATE OR REPLACE FUNCTION cascade_logical_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- posts.deleted_at が NULL から日時に変わった場合のみ実行
  IF (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL) THEN
    UPDATE public_cards SET deleted_at = NEW.deleted_at WHERE post_id = NEW.id;
    UPDATE private_cards SET deleted_at = NEW.deleted_at WHERE post_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- トリガーの登録 (posts テーブルの更新後)
DROP TRIGGER IF EXISTS tr_cascade_logical_delete ON posts;
CREATE TRIGGER tr_cascade_logical_delete
AFTER UPDATE OF deleted_at ON posts
FOR EACH ROW
EXECUTE FUNCTION cascade_logical_delete();

-- 3. 動作確認用のコメント
-- これで、アプリ側からは `posts` テーブルを1回更新するだけで、すべてが連動して消えるようになります。
