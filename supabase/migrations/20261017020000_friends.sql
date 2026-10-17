-- ==========================================
-- リニューアル 02: 友達機能
--   - friendships テーブル (無向の一意ペア / 自己申請禁止)
--   - are_friends() ヘルパー (SECURITY DEFINER)
--   - 申請/承認/拒否/キャンセル/解除 関数 (状態遷移をサーバーで強制)
-- 冪等。再実行可能。
-- ==========================================

CREATE TABLE IF NOT EXISTS friendships (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at  TIMESTAMPTZ,
  CONSTRAINT friendships_no_self CHECK (requester_id <> addressee_id)
);

-- 無向の一意性: 同一ペアに付き1行のみ (pending/accepted どちらでも)
CREATE UNIQUE INDEX IF NOT EXISTS friendships_unique_pair
  ON friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));

CREATE INDEX IF NOT EXISTS friendships_addressee_idx ON friendships (addressee_id, status);
CREATE INDEX IF NOT EXISTS friendships_requester_idx ON friendships (requester_id, status);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- SELECT: 当事者のみ
DROP POLICY IF EXISTS "Users can view their own friendships" ON friendships;
CREATE POLICY "Users can view their own friendships" ON friendships
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- INSERT/UPDATE/DELETE ポリシーは作らない。
-- => authenticated からの直接書き込みは RLS で拒否。下記 SECURITY DEFINER 関数経由のみ。

-- ------------------------------------------
-- ヘルパー: 2者が承認済み友達か
-- ------------------------------------------
CREATE OR REPLACE FUNCTION are_friends(a UUID, b UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM friendships
    WHERE status = 'accepted'
      AND (
        (requester_id = a AND addressee_id = b) OR
        (requester_id = b AND addressee_id = a)
      )
  );
$$;

-- ------------------------------------------
-- 申請
-- ------------------------------------------
CREATE OR REPLACE FUNCTION send_friend_request(p_addressee UUID)
RETURNS friendships
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_requester UUID := auth.uid();
  v_recent    INTEGER;
  v_row       friendships;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF v_requester = p_addressee THEN
    RAISE EXCEPTION 'cannot send a friend request to yourself';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_addressee) THEN
    RAISE EXCEPTION 'addressee not found';
  END IF;

  -- 既存関係 (pending/accepted どちらでも) があれば重複禁止
  IF EXISTS (
    SELECT 1 FROM friendships
    WHERE LEAST(requester_id, addressee_id)    = LEAST(v_requester, p_addressee)
      AND GREATEST(requester_id, addressee_id) = GREATEST(v_requester, p_addressee)
  ) THEN
    RAISE EXCEPTION 'a friendship or pending request already exists';
  END IF;

  -- レート制限: 同一申請者からは直近10秒に1件まで
  SELECT COUNT(*) INTO v_recent FROM friendships
    WHERE requester_id = v_requester AND created_at > now() - interval '10 seconds';
  IF v_recent > 0 THEN
    RAISE EXCEPTION 'rate limit: please wait a moment before sending another request';
  END IF;

  INSERT INTO friendships (requester_id, addressee_id, status)
  VALUES (v_requester, p_addressee, 'pending')
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

-- ------------------------------------------
-- 承認 / 拒否 (addressee のみ)
--   accept -> accepted, reject -> 行削除 (再申請可 / 送信者へ拒否通知なし)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION respond_friend_request(p_id UUID, p_accept boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row friendships;
BEGIN
  SELECT * INTO v_row FROM friendships WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
  IF v_row.addressee_id <> v_uid THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_row.status <> 'pending' THEN RAISE EXCEPTION 'request is not pending'; END IF;

  IF p_accept THEN
    UPDATE friendships SET status = 'accepted', responded_at = now() WHERE id = p_id;
  ELSE
    DELETE FROM friendships WHERE id = p_id;
  END IF;
END;
$$;

-- ------------------------------------------
-- キャンセル (requester のみ / pending のみ)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION cancel_friend_request(p_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row friendships;
BEGIN
  SELECT * INTO v_row FROM friendships WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
  IF v_row.requester_id <> v_uid THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_row.status <> 'pending' THEN RAISE EXCEPTION 'only pending requests can be cancelled'; END IF;
  DELETE FROM friendships WHERE id = p_id;
END;
$$;

-- ------------------------------------------
-- 解除 (accepted を削除 / Private 閲覧権は即失効)
-- ------------------------------------------
CREATE OR REPLACE FUNCTION remove_friend(p_other UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  DELETE FROM friendships
  WHERE status = 'accepted'
    AND ((requester_id = v_uid   AND addressee_id = p_other)
      OR (requester_id = p_other AND addressee_id = v_uid));
END;
$$;

-- 実行権限
REVOKE EXECUTE ON FUNCTION send_friend_request(UUID)      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION respond_friend_request(UUID, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION cancel_friend_request(UUID)    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION remove_friend(UUID)            FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION send_friend_request(UUID)      TO authenticated;
GRANT  EXECUTE ON FUNCTION respond_friend_request(UUID, boolean) TO authenticated;
GRANT  EXECUTE ON FUNCTION cancel_friend_request(UUID)    TO authenticated;
GRANT  EXECUTE ON FUNCTION remove_friend(UUID)            TO authenticated;
-- are_friends は RLS ポリシー評価でも使うため anon/authenticated に許可
GRANT  EXECUTE ON FUNCTION are_friends(UUID, UUID)        TO authenticated, anon;
