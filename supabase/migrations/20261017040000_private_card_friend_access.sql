-- ==========================================
-- リニューアル 04: Private カードの友達閲覧 (仕様6)
--   既存の private_cards SELECT (本人のみ) を
--   「本人 または 承認済み友達」に更新する。
-- 依存: 02(are_friends)
-- 冪等。再実行可能。
--
-- 【重要な注意 / 要レビュー】
--   posts テーブルの既存 SELECT ポリシーは
--     USING (deleted_at IS NULL OR auth.uid() = user_id)
--   となっており、削除されていない posts 行は「全員閲覧可」。
--   posts には comment / public_image_url / private_image_url が含まれるため、
--   Private情報の一部が友達以外にも読める既存の穴がある。
--   本マイグレーションでは既存Map/カード表示を壊さないため posts RLS は変更しない。
--   posts の厳格化は、認証/友達フェーズでクエリ経路を確認したうえで別途対応する
--   (docs/renewal/db-design.md §8, apply-guide の「要対応」を参照)。
-- ==========================================

DROP POLICY IF EXISTS "Users can see their own active private cards" ON private_cards;
DROP POLICY IF EXISTS "Owner or friends can view private cards" ON private_cards;
CREATE POLICY "Owner or friends can view private cards" ON private_cards
  FOR SELECT USING (
    auth.uid() = user_id
    OR are_friends(auth.uid(), user_id)
  );
