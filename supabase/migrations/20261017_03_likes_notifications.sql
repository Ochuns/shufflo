-- ==========================================
-- リニューアル 03: いいね・通知
--   - notifications テーブル (like / friend_request の2種のみ)
--   - likes テーブル (post 単位 / 一意制約)
--   - toggle_like() 関数 (友達&非所有者&閲覧可をサーバーで強制)
--   - 通知生成トリガー (likes INSERT / friendships pending INSERT)
-- 依存: 01(users), 02(friendships, are_friends)
-- 冪等。再実行可能。
-- ==========================================

-- ------------------------------------------
-- 通知
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          TEXT NOT NULL CHECK (type IN ('like','friend_request')),
  actor_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id       UUID REFERENCES posts(id) ON DELETE CASCADE,
  friendship_id UUID REFERENCES friendships(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS notifications_recipient_idx
  ON notifications (recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON notifications (recipient_id) WHERE read_at IS NULL;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- SELECT / UPDATE(既読化) は受信者本人のみ
DROP POLICY IF EXISTS "Recipients can view their notifications" ON notifications;
CREATE POLICY "Recipients can view their notifications" ON notifications
  FOR SELECT USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS "Recipients can mark their notifications read" ON notifications;
CREATE POLICY "Recipients can mark their notifications read" ON notifications
  FOR UPDATE USING (recipient_id = auth.uid()) WITH CHECK (recipient_id = auth.uid());

-- 列レベル制限 (C5対策): RLSは列を制限できないため、受信者が read_at 以外
-- (type/actor_id/post_id/friendship_id 等) を改ざんできないよう列権限で縛る。
-- Supabase既定の UPDATE 全列権限を剥奪し、read_at 列のみ許可する。
REVOKE UPDATE ON notifications FROM anon, authenticated;
GRANT  UPDATE (read_at) ON notifications TO authenticated;
-- INSERT ポリシーなし => トリガー(SECURITY DEFINER)経由のみ。アプリから二重通知できない。

-- ------------------------------------------
-- いいね (post 単位。dual-card で共有される安定ID)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT likes_unique_user_post UNIQUE (user_id, post_id)
);
CREATE INDEX IF NOT EXISTS likes_post_idx ON likes (post_id);

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- SELECT: 自分のいいね or 自分のpostへのいいね (いいね数/いいねした人を自分のカードで確認)
DROP POLICY IF EXISTS "View own likes or likes on own posts" ON likes;
CREATE POLICY "View own likes or likes on own posts" ON likes
  FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM posts p WHERE p.id = likes.post_id AND p.user_id = auth.uid())
  );
-- INSERT/DELETE ポリシーなし => toggle_like() 経由のみ

-- ------------------------------------------
-- toggle_like: いいね切り替え。戻り値は切替後の状態 (true=liked)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION toggle_like(p_post_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_owner UUID;
  v_exists BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT user_id INTO v_owner FROM posts WHERE id = p_post_id AND deleted_at IS NULL;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'post not found'; END IF;
  IF v_owner = v_uid THEN RAISE EXCEPTION 'cannot like your own card'; END IF;

  SELECT EXISTS(SELECT 1 FROM likes WHERE user_id = v_uid AND post_id = p_post_id) INTO v_exists;
  IF v_exists THEN
    -- 取り消し (自分のいいねの撤回はいつでも可)
    DELETE FROM likes WHERE user_id = v_uid AND post_id = p_post_id;
    RETURN false;
  END IF;

  -- 新規いいね: 承認済み友達のカードに限る (public/private 問わず友達は閲覧可)
  IF NOT are_friends(v_uid, v_owner) THEN
    RAISE EXCEPTION 'you can only like a friend''s card';
  END IF;

  INSERT INTO likes (user_id, post_id) VALUES (v_uid, p_post_id);
  RETURN true;
END;
$$;

-- ------------------------------------------
-- 通知生成トリガー
-- ------------------------------------------

-- like -> post 所有者へ通知
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM posts WHERE id = NEW.post_id;
  IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
    INSERT INTO notifications (recipient_id, type, actor_id, post_id)
    VALUES (v_owner, 'like', NEW.user_id, NEW.post_id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_notify_on_like ON likes;
CREATE TRIGGER tr_notify_on_like
  AFTER INSERT ON likes
  FOR EACH ROW EXECUTE FUNCTION notify_on_like();

-- friend request (pending) -> addressee へ通知
CREATE OR REPLACE FUNCTION notify_on_friend_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    INSERT INTO notifications (recipient_id, type, actor_id, friendship_id)
    VALUES (NEW.addressee_id, 'friend_request', NEW.requester_id, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_notify_on_friend_request ON friendships;
CREATE TRIGGER tr_notify_on_friend_request
  AFTER INSERT ON friendships
  FOR EACH ROW EXECUTE FUNCTION notify_on_friend_request();

-- 実行権限
REVOKE EXECUTE ON FUNCTION toggle_like(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION toggle_like(UUID) TO authenticated;
