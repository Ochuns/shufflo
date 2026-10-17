-- ==========================================
-- リニューアル 08: posts の公開範囲厳格化 (C6 対策 / 仕様6・15)
--
-- 背景:
--   既存の posts SELECT ポリシーは USING (deleted_at IS NULL OR auth.uid() = user_id)
--   で、削除されていない posts 行は「全員閲覧可」。posts には comment /
--   public_image_url / private_image_url が含まれるため、Private専用の体験でも
--   その本文・画像URLが友達以外に読めてしまう。
--   04 で private_cards を友達限定にしても、中身の多くが posts 側にあるため
--   実効的な秘匿にならない。本マイグレーションで posts を次の方針に是正する:
--
--     - 本人            : 常に閲覧可 (削除済み含む)
--     - Public/デュアル  : public_cards を持つ post は全員閲覧可 (Map探索を維持)
--     - Private専用      : public_cards を持たない post は 本人 または 承認済み友達 のみ
--
-- 依存: 02(are_friends)
-- 冪等。再実行可能。
--
-- 【要検証 / 適用前に確認】
--   この変更は posts の SELECT を絞る。既存の Map / カード一覧 / プロフィール /
--   デッキ表示が posts を直接読むクエリ経路に依存していないかを、適用後に必ず
--   動作確認すること。Map探索は RPC get_nearby_public_cards (SECURITY DEFINER)
--   が public_cards を返すため影響しない想定。
--
-- 【ロールバック】適用前の挙動に戻す場合は以下を実行:
--   DROP POLICY IF EXISTS "Anyone can see active posts" ON posts;
--   CREATE POLICY "Anyone can see active posts" ON posts
--     FOR SELECT USING (deleted_at IS NULL OR auth.uid() = user_id);
--
-- 【残存課題 / 要検討】
--   デュアルカード(公開+非公開を両方作成)の post は public_cards を持つため
--   全員閲覧可のまま。この場合 posts.private_image_url / 非公開コメントは
--   依然として読める。完全な秘匿には「非公開フィールドを posts から分離する」
--   スキーマ変更とアプリ改修が必要。認証/投稿フェーズで方針を決める。
-- ==========================================

DROP POLICY IF EXISTS "Anyone can see active posts" ON posts;
CREATE POLICY "Anyone can see active posts" ON posts
  FOR SELECT USING (
    auth.uid() = user_id
    OR (
      deleted_at IS NULL
      AND (
        EXISTS (
          SELECT 1 FROM public_cards pc
          WHERE pc.post_id = posts.id AND pc.deleted_at IS NULL
        )
        OR are_friends(auth.uid(), user_id)
      )
    )
  );
