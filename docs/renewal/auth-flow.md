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

## 検証済み
- `flutter analyze`（auth / routing / main）: エラー0。
- マイグレーション `09`: 適用・トリガー（username反映 / デフォルト付与 / 大小無視重複拒否）・`is_username_available` をローカルPostGISで確認。

## このチャンクで未実装（次チャンク）
- **アカウント削除**: `AuthRepository.deleteAccount` は実装済みだが、呼び出す Edge Function `delete-account`（service role で `auth.admin.deleteUser` → `public.users` カスケード削除）は未作成・未デプロイ。削除確認UI も未。
- **アカウント設定UI**: ログアウト／退会ボタンの常設導線（現状は確認待ち/変換画面の「別アカウント」のみ）。プロフィール編集はプロフィールフェーズ（feature/friends-social）。

## 適用・運用で必要な設定（ダッシュボード / SQL外）
- Supabase: **Email プロバイダ有効化 + Confirm email を ON**（必要なら SMTP 設定）。これが無いとメール確認フローが動かない。
- マイグレーション `20261017_09_auth_profile_bootstrap.sql` の適用。
- （任意）メール確認リンクのディープリンク対応は将来拡張。現状は「確認した（再読込）」ボタン / 確認後ログインで対応。
