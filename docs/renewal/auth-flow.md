# 認証フロー設計（feature/auth-account）

仕様§7 に対応。既存の「起動時に無条件で匿名ログイン」を廃止し、メール認証ゲートに置き換える。
公開範囲・ユーザー名一意性などの最終強制はサーバー側（RLS / 関数 / トリガー）で行う。

## 認証状態と遷移（ルーターの redirect ゲート）

`AuthRepository.status` が現在状態を4分類し、`app_router.dart` の `redirect` が誘導する。

| 状態 | 判定 | 誘導先 |
|---|---|---|
| `unauthenticated` | セッションなし | `/login`（`/signup`・`/verify-email` は到達可） |
| `anonymous` | `user.isAnonymous` | `/welcome`（正式アカウントへ引き継ぎ） |
| `unconfirmed` | セッションあり & `emailConfirmedAt==null` | `/verify-email` |
| `authenticated` | 確認済み | 本編（`/map` 等） |

`refreshListenable` に認証状態ストリームを橋渡し（`GoRouterRefreshStream`）し、状態変化で自動再評価。

## 画面
- `/login` — ログイン
- `/signup` — 新規登録（username/email/password）→ 成功後 `/verify-email`
- `/verify-email` — メール確認待ち（再送 / 「確認した（再読込）」/ 別アカウント）
- `/welcome` — 匿名→正式アカウント変換（同一UID維持。送信後はインラインで確認待ち表示）

## 新規登録とユーザー名
- `signUp` は username を `data`（メタデータ）に載せる。メール確認必須のためセッションは作られない想定。
- DBトリガー `handle_new_user`（`09`）が `auth.users` 作成時に `public.users` を自動生成。
  username はメタデータから。重複時は UNIQUE 違反でサインアップ自体が失敗（= サーバー側で一意性強制）。
- UX用に `is_username_available` RPC で事前チェック。

## 匿名アカウントの移行（§7.4）
- `convertAnonymous`: `auth.updateUser(email, password)` で同一UIDのまま email を設定（確認がトリガー）。
  併せて `users.username` を更新（RLSで本人のみ / UNIQUEで一意）。確認完了で `is_anonymous` 解除 → 本編へ。
- 新UID発行＋データコピーは行わないため、カード・デッキ等の参照は壊れない。

## アカウント削除（§7.5）
- 導線: プロフィール右上の設定アイコン → `/account`（アカウント設定）→「アカウントを削除」。
- 確認ダイアログで**パスワード再入力（本人確認）**を要求。
- `AuthRepository.deleteAccount`: 再認証 → Edge Function `delete-account` を呼ぶ → signOut。
- Edge Function `supabase/functions/delete-account/index.ts`: 呼び出し元JWTで本人特定 →
  service role で `auth.admin.deleteUser(uid)`。`public.users` への ON DELETE CASCADE（migration 10）で
  友達/いいね/通知/進捗/クーポン/カード/デッキ等の個人データが連鎖削除される。
  Service Role Key は関数の環境変数にのみ存在しクライアントに置かない。
- ログアウトも `/account` から可能。

## 検証済み（ローカル PostGIS + flutter analyze）
- `flutter analyze`（auth / routing / profile / main）: エラー0。
- `09`: トリガー（username反映 / デフォルト付与 / 大小無視重複拒否）・`is_username_available`。
- `10`: `auth.users` 1件削除で `users/posts/public_cards/private_cards/friendships/likes/notifications` が
  すべてカスケード削除されること、他ユーザーのデータが残ることを確認（退会がブロックされない）。

## 残課題（別フェーズ）
- プロフィール編集（アバター/自己紹介/username変更）はプロフィールフェーズ（feature/friends-social）。
- メール確認リンクのディープリンク自動処理は将来拡張（現状は「確認した（再読込）」/ 確認後ログイン）。

## 適用・運用で必要な設定（ダッシュボード / SQL外）
- Supabase: **Email プロバイダ有効化 + Confirm email を ON**（必要なら SMTP 設定）。無いとメール確認フローが動かない。
- マイグレーション `20261017_09` / `20261017_10` の適用。
- Edge Function デプロイ: `supabase functions deploy delete-account`（SUPABASE_URL / ANON_KEY /
  SERVICE_ROLE_KEY は Supabase が自動注入）。
