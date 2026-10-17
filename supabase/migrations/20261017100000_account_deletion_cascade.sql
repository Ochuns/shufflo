-- ==========================================
-- リニューアル 10: アカウント削除のためのカスケード整備 (仕様7.5)
--
-- 目的: Edge Function が auth.users を1件削除するだけで、
--       public.users -> 各個人データ が連鎖削除されるようにする。
--
-- 現状の問題:
--   - public.users.id -> auth.users(id) は ON DELETE 指定なし(RESTRICT)
--     => auth.admin.deleteUser が public.users 行に阻まれて失敗する。
--   - posts/public_cards/private_cards の user_id/post_id FK も CASCADE でない
--     => public.users 削除が posts 等に阻まれる。
--
-- 対応: 下記FKを ON DELETE CASCADE に張り替える。
--   (decks.user_id / user_pinned_cards / リニューアルで追加した各テーブルは既に CASCADE)
--   locations は共有データのため対象外。
--
-- FK名のドリフトに備え、(テーブル,列,参照先) から現行FKを探して張り替える。
-- 冪等。再実行可能。
-- ==========================================

CREATE OR REPLACE FUNCTION _recreate_fk_cascade(
  p_table regclass, p_column text, p_ref regclass, p_ref_col text, p_newname text
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_name text;
BEGIN
  SELECT con.conname INTO v_name
  FROM pg_constraint con
  WHERE con.contype = 'f'
    AND con.conrelid = p_table
    AND con.confrelid = p_ref
    AND (SELECT attname FROM pg_attribute
         WHERE attrelid = p_table AND attnum = con.conkey[1]) = p_column;

  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', p_table::text, v_name);
  END IF;

  EXECUTE format(
    'ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %s(%I) ON DELETE CASCADE',
    p_table::text, p_newname, p_column, p_ref::text, p_ref_col
  );
END;
$$;

-- public.users 行削除が auth.users 削除で連鎖するように
SELECT _recreate_fk_cascade('public.users','id','auth.users','id','users_id_fkey');

-- posts / cards を所有者削除で連鎖削除
SELECT _recreate_fk_cascade('public.posts','user_id','public.users','id','posts_user_id_fkey');
SELECT _recreate_fk_cascade('public.public_cards','user_id','public.users','id','public_cards_user_id_fkey');
SELECT _recreate_fk_cascade('public.private_cards','user_id','public.users','id','private_cards_user_id_fkey');

-- post 削除で紐づくカードも連鎖削除 (RESTRICT混在によるカスケード阻害を防ぐ)
SELECT _recreate_fk_cascade('public.public_cards','post_id','public.posts','id','public_cards_post_id_fkey');
SELECT _recreate_fk_cascade('public.private_cards','post_id','public.posts','id','private_cards_post_id_fkey');

DROP FUNCTION _recreate_fk_cascade(regclass, text, regclass, text, text);
