# リニューアルDB 適用手順書

対象マイグレーション（`supabase/migrations/` 配下、依存順）:
1. `20261017_01_profiles.sql`
2. `20261017_02_friends.sql`
3. `20261017_03_likes_notifications.sql`
4. `20261017_04_private_card_friend_access.sql`
5. `20261017_05_stores_themes.sql`
6. `20261017_06_visits_progress.sql`
7. `20261017_07_coupons.sql`
8. `20261017_08_posts_privacy_hardening.sql`

すべて冪等（`IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE`）で、PostGIS 15 のローカル環境で適用・再適用・挙動検証済み。

---

## 0. 適用前チェック（必須）

1. **本番前にステージング/バックアップ**で先に適用すること。
2. 既存DBに `username` の大小無視の重複がないか確認（あると `01` が中断する。中断は意図的な安全策）:
   ```sql
   SELECT lower(username), count(*) FROM users GROUP BY lower(username) HAVING count(*) > 1;
   ```
3. `pgcrypto` のインストール先スキーマを確認（`05` は `CREATE EXTENSION IF NOT EXISTS pgcrypto` を実行。関数は `public, extensions` 両対応済み）。

## 1. マイグレーション適用

### 方法A: Supabase CLI（プロジェクトが link 済みの場合）
```bash
# 既存の supabase/migrations をリポジトリに持っているので push するだけ
supabase db push
```
注: `database/supabase/migrations/supabase_schema_update.sql` は別ディレクトリにあり CLI の管理対象外（過去に手動適用された想定）。新規8本は `supabase/migrations/` 配下なので push 対象。

### 方法B: ダッシュボードのSQLエディタ
`20261017_01` 〜 `20261017_08` を**番号順に**コピペ実行。

## 2. 適用後の必須動作確認（リグレッション）

`08`（posts公開範囲の厳格化）は SELECT を絞るため、特に確認:

- [ ] **Map探索**: 近くのPublicカードが従来どおり表示される（RPC `get_nearby_public_cards` は SECURITY DEFINER で影響しない想定だが要確認）
- [ ] **My Cards / プロフィール**: 自分のカード一覧が表示される
- [ ] **デッキ**: 作成・再生が従来どおり
- [ ] **カード詳細**: 他人のPublicカード詳細が開ける
- [ ] アプリが起動し、匿名ログインが従来どおり動く（`users` のRLS有効化後も読み書きできる＝user行作成が `id=auth.uid()` で行われていること）

問題があれば `08` はロールバック可能（ファイル冒頭のロールバックSQL参照）。

## 3. 店舗・テーマ・QRトークンの登録（管理操作 / service role or DB直）

管理UIは未実装のため、DBへ直接登録する。

```sql
-- 店舗
INSERT INTO stores (id, name, location)
VALUES (gen_random_uuid(), '会津ラーメン○○', ST_Point(139.9290, 37.4946)::geography)
RETURNING id;   -- 返ってきた store_id を控える

-- QRトークン（平文は印刷用。DBにはハッシュのみ保存される）
SELECT set_store_qr_token('<store_id>', '<印刷する推測困難なトークン>');

-- テーマ
INSERT INTO themes (id, name, sort_order, reward_title, reward_description)
VALUES (gen_random_uuid(), '会津ラーメン巡り', 10, '無料トッピング', '対象店で使える') RETURNING id;

-- テーマ対象店舗（M:N）
INSERT INTO theme_stores (theme_id, store_id) VALUES ('<theme_id>', '<store_id>');

-- 報酬の利用可能店舗（M:N）
INSERT INTO theme_reward_stores (theme_id, store_id) VALUES ('<theme_id>', '<store_id>');
```
QRコードには `set_store_qr_token` に渡した**平文トークン**を埋め込む。アプリはスキャンした平文を `verify_visit(store_id, lat, lon, token)` に渡し、サーバーがハッシュ照合＋GPS判定する。

## 4. アプリ側（Claudeが別途コード実装）が呼ぶサーバー関数（RPC）

| 用途 | RPC |
|---|---|
| 友達申請/承認/取消/解除 | `send_friend_request` / `respond_friend_request(id, accept)` / `cancel_friend_request(id)` / `remove_friend(other)` |
| いいね切替 | `toggle_like(post_id)` → 戻り値 true=liked |
| 訪問確認 | `verify_visit(store_id, lat, lon, qr_token)` |
| 進捗付与（カード保存後） | `complete_theme_visit(verification_id, post_id)` |
| クーポン発行/利用 | `claim_theme_reward(theme_id)` / `use_coupon(coupon_id)` |

通知生成（いいね/友達申請）はトリガーで自動。アプリから作成不要。

## 5. 別途ダッシュボード設定が必要なもの（SQL外）

- **メール認証の有効化**（Authentication → Providers → Email、Confirm email を ON、必要なら SMTP 設定）。認証フェーズのコード実装と対で必要。
- **アカウント削除の Edge Function**（service role で `auth.admin.deleteUser` → `public.users` 削除 → 個人データは `ON DELETE CASCADE` で一括削除）。認証フェーズで実装・デプロイ（`supabase functions deploy`）。Service Role Key はクライアントに置かない。

## 6. 既知の注意点

- `database/supabase/migrations/supabase_schema_update.sql:65` の `private_cards_location_idx` は `private_cards.location_coords` を参照するが初期スキーマに同列がない。既存DBで適用済みか／エラーになっていないかを確認（本リニューアルでは変更しない）。
- デュアルカードの `posts.private_image_url`・非公開コメントは `08` 適用後も公開のまま（db-design §10 の残存課題）。完全秘匿は後続フェーズで対応。
