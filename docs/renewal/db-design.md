# Shufflo リニューアル DB設計書（全機能分）

対象: 認証 / 友達・いいね・通知 / テーマ収集 / GPS・QR訪問確認 / クーポン
前提: 既存スキーマ（`users`, `locations`, `posts`, `public_cards`, `private_cards`, `decks`, `user_pinned_cards`）を再利用し、既存挙動（Map探索・カード作成・デッキ・論理削除）を壊さない。

本書は仕様書 §14・§15 に対応する**レビュー用**の設計で、実体は `supabase/migrations/20261017_*.sql` に実装する。適用はユーザーが行う（`docs/renewal/apply-guide.md` 参照）。

---

## 0. 設計方針と全体像

- 既存の **dual-card モデル**（1つの `posts` に対し `public_cards` / `private_cards` が最大1枚ずつ）を維持する。
- 新機能のテーブルはすべて `users(id)` を外部キーにし、**ユーザー名変更で参照が壊れない**ようにする（仕様14）。
- **アカウント削除**時に個人データを確実に消すため、個人データ系テーブルは `users(id)` に対し `ON DELETE CASCADE`。Auth ユーザー削除（Edge Function, service role）→ `public.users` 行削除 → カスケードで全個人データ削除、という流れ。
- **サーバー側整合性**（仕様15）: 公開範囲・いいね可否・進捗付与・クーポン発行/使用などの判定は RLS と `SECURITY DEFINER` 関数（トランザクション）で強制し、クライアントの自己申告を信用しない。
- RLS の再帰・性能問題を避けるため、友達判定など横断チェックは `SECURITY DEFINER` のヘルパー関数（`public.are_friends` 等）経由で行う。

### いいね/通知の対象識別についての決定
いいね・通知は **`post_id`（体験の安定ID）** を対象にする。理由:
- 1投稿に public/private 両カードが存在しうるため、`card_id` 単位だと重複・曖昧になる。
- `post_id` は dual-card で共有される安定IDで、論理削除（`deleted_at`）後も行が残り履歴参照できる。
- 画面遷移時は `post_id` から「閲覧可能な方のカード」をアプリ側で解決して詳細画面を開く。

---

## 1. プロフィール（既存 `users` を拡張）

新テーブルは作らず既存 `users` を拡張する。

| 変更 | 内容 |
|---|---|
| 列追加 | `bio TEXT`（≤140、CHECK制約） |
| 一意制約 | `username` に **大小無視のUNIQUE**（`UNIQUE INDEX ON lower(username)`） |
| RLS | 現状 `users` は RLS 未設定＝誰でも更新可能な欠陥。RLS を有効化し「SELECTは全員可（公開プロフィール）/ INSERT・UPDATE は本人のみ / username・idは不変に近い扱い」 |

- 既存データに username 重複がある場合、UNIQUE INDEX 作成が失敗しうる。マイグレーションは重複検出を含め、重複があれば中断して手動対応を促す（データ破壊を避ける, 仕様§2禁止事項）。
- アバター/自己紹介は登録後設定（列はNULL許容）。

RLS ポリシー:
- `SELECT`: `true`（username/avatar/bio は公開情報。メール等の個人情報は `auth.users` 側にあり `public.users` には持たない）
- `INSERT`: `auth.uid() = id`
- `UPDATE`: `auth.uid() = id`（`id` 変更は不可）
- `DELETE`: 不可（アカウント削除は Edge Function 経由のみ）

---

## 2. 友達機能

### `friendships`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| requester_id | UUID FK users ON DELETE CASCADE | 申請者 |
| addressee_id | UUID FK users ON DELETE CASCADE | 申請先 |
| status | TEXT CHECK in ('pending','accepted') | 拒否は行を残さず削除（再申請可のため） |
| created_at | TIMESTAMPTZ | 申請日時 |
| responded_at | TIMESTAMPTZ | 承認日時 |

制約:
- `CHECK (requester_id <> addressee_id)` 自己申請禁止
- **無向の一意性**: `UNIQUE (least(requester,addressee), greatest(...))` を関数インデックスで表現し、同一ペアの重複関係を禁止（pending/accepted どちらでも1行）
- 友達人数上限なし

状態遷移（関数で強制, RLSは最小限）:
- 送信: `send_friend_request(addressee)` — 既存関係なし/自分でない/**直近N秒のレート制限**（連続申請抑止, 仕様8.2）
- 承認: `respond_friend_request(id, accept bool)` — addressee のみ。accept→status=accepted+responded_at、reject→行削除（送信者へ拒否通知なし, 仕様8.2）
- キャンセル: `cancel_friend_request(id)` — requester のみ、pending のみ
- 解除: `remove_friend(other_user)` — accepted 行を削除。解除で**即座にPrivate閲覧権失効**（§8.3 / §2参照）。過去のいいね・通知履歴は残す

RLS:
- `SELECT`: 自分が当事者（requester or addressee）の行のみ
- `INSERT/UPDATE/DELETE`: 直接は拒否。上記 `SECURITY DEFINER` 関数経由のみ（不正な状態遷移を防止）

ヘルパー: `public.are_friends(a UUID, b UUID) RETURNS boolean`（accepted が存在するか。SECURITY DEFINER）

---

## 3. いいね・通知

### `likes`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK users ON DELETE CASCADE | いいねした人 |
| post_id | UUID FK posts ON DELETE CASCADE | 対象体験 |
| created_at | TIMESTAMPTZ | |

- `UNIQUE (user_id, post_id)` 重複いいね禁止（仕様9.1）
- 付与条件（関数 `toggle_like(post_id)` で強制）: 対象postの所有者が**自分でない** かつ **現在friend** かつ（postが public または private-but-friend で閲覧可）
- 友達解除後は新規いいね不可。**解除前のいいねは削除しない**（履歴保持）

RLS:
- `SELECT`: 自分のいいね、または**自分のpostに対するいいね**（いいね数・いいねした人を自分のカード詳細で確認, 仕様9.1）
- `INSERT/DELETE`: 直接拒否。`toggle_like` 関数経由のみ（friendチェックをサーバーで）

### `notifications`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| recipient_id | UUID FK users ON DELETE CASCADE | 受信者 |
| type | TEXT CHECK in ('like','friend_request') | 2種のみ（仕様9.2） |
| actor_id | UUID FK users ON DELETE CASCADE | 行為者 |
| post_id | UUID FK posts ON DELETE CASCADE NULL | like時の対象 |
| friendship_id | UUID FK friendships ON DELETE CASCADE NULL | friend_request時の対象 |
| created_at | TIMESTAMPTZ | |
| read_at | TIMESTAMPTZ NULL | 既読日時 |

- 通知生成は**トリガー**で行う（like挿入時 / friendship pending挿入時）。アプリから二重に作らない（二重通知防止, 仕様14）
- friend承認/キャンセル/解除時の通知は作らない（仕様: 通知は「いいね」「友達申請」のみ）
- 友達解除後も通知履歴は残すが、**閲覧権を失ったPrivateカードの内容は表示しない**（アプリ側 + RLSで、like通知からの遷移時に閲覧可否を再判定）

RLS:
- `SELECT`/`UPDATE(read_at)`: `recipient_id = auth.uid()` のみ（本人だけ閲覧・既読化, 仕様15）
- `INSERT`: 直接拒否（トリガーのSECURITY DEFINERのみ）

### Private カード閲覧の RLS 更新（仕様6）
既存 `private_cards` SELECT は「本人のみ」。これを **「本人 または 承認済み友達（`are_friends`）」** に更新する。
- `posts`・`locations` 側も、Private情報が友達以外に漏れないよう整合を取る（下記 §8 注意点参照）。

---

## 4. 店舗・テーマ

### `stores`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | 固定ID（店名変更で参照が壊れない, 仕様14） |
| name | TEXT | |
| location | GEOGRAPHY(POINT) | サーバー側距離計算用 |
| is_active | BOOLEAN DEFAULT true | |
| created_at | TIMESTAMPTZ | |

- GiST インデックス（location）
- RLS `SELECT`: active のみ全員可。INSERT/UPDATE/DELETEはクライアント不可（管理はDB直/将来の管理UI）

### `store_qr_tokens`（QRトークン — クライアント非公開）
QRトークンの**ハッシュ**は `stores` に置かず別テーブルに分離し、**RLS有効＋ポリシーなし**で `authenticated`/`anon` からは一切読めないようにする（`verify_visit()` の SECURITY DEFINER だけが照合に使用）。平文は保存しない（仕様14）。
| 列 | 型 | 説明 |
|---|---|---|
| store_id | UUID PK FK stores | |
| token_hash | TEXT UNIQUE | sha256(平文トークン) |
| created_at | TIMESTAMPTZ | |

登録は `set_store_qr_token(store_id, plain_token)`（service role / DB直のみ）で行う。

### `themes`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| name | TEXT | |
| sort_order | INTEGER | 安定した表示順（同率時の安定ソート, 仕様5.4/10.1） |
| reward_title | TEXT | 報酬内容 |
| reward_description | TEXT | |
| is_active | BOOLEAN DEFAULT true | |
| created_at | TIMESTAMPTZ | |

### `theme_stores`（M:N 対象店舗）
`(theme_id, store_id)` PK。テーマの対象店舗を**固定IDで判定**（曖昧一致・AI推測を使わない, 仕様10.1）。

### `theme_reward_stores`（報酬の利用可能店舗）
`(theme_id, store_id)` PK。クーポン利用可能店舗（仕様12.3）。

RLS: themes/theme_stores/theme_reward_stores とも `SELECT` active 全員可、書き込みはクライアント不可。

---

## 5. 訪問確認・訪問記録・テーマ進捗

### `visit_verifications`（訪問確認状態, 24h）
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK users ON DELETE CASCADE | |
| store_id | UUID FK stores | |
| gps_verified | BOOLEAN | サーバーで距離≤100m判定 |
| qr_verified | BOOLEAN | サーバーでトークン照合 |
| verified_at | TIMESTAMPTZ | 成立時刻 |
| expires_at | TIMESTAMPTZ | verified_at + 24h |
| consumed | BOOLEAN DEFAULT false | カード保存で消費済みか |
| created_at | TIMESTAMPTZ | |

- 発行は `verify_visit(store_id, lat, lon, qr_token)`（SECURITY DEFINER）のみ。**距離計算はサーバー**（ST_DWithin 100m）、**QRトークンはハッシュ照合でstore_idを解決**。GPSとQR双方成立時のみ行を作成。
- クライアントが任意の確認IDを作って進捗を付けることは不可（RLS: INSERT直接拒否, 進捗付与は関数のみ）。
- 期限切れ（`now() > expires_at`）は無効。期限切れからは進捗を付けない（仕様11）。
- 重複処理防止（同一ユーザー・店舗の有効な未消費確認は再利用）。レート制限。

RLS: `SELECT` 本人のみ。INSERT/UPDATE 直接拒否（関数のみ）。

### `visited_records`（検証済み訪問記録 — カードと分離）
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK users ON DELETE CASCADE | |
| store_id | UUID FK stores | |
| post_id | UUID FK posts ON DELETE SET NULL | 生成元カード（論理削除後も記録は残す） |
| verification_id | UUID FK visit_verifications | |
| visited_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | |

- **投稿を論理削除しても訪問記録は維持**（仕様10.3/13）。post は論理削除（行は残る）なので `post_id` は保持される。万一の物理削除に備え `ON DELETE SET NULL`。
- RLS `SELECT` 本人のみ。書き込みは関数のみ。

### `theme_progress`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK users ON DELETE CASCADE | |
| theme_id | UUID FK themes | |
| cycle_number | INTEGER | サイクル番号（1始まり） |
| store_id | UUID FK stores | |
| visited_record_id | UUID FK visited_records | |
| earned_at | TIMESTAMPTZ | |

- **`UNIQUE (user_id, theme_id, cycle_number, store_id)`**（同一店舗を同一サイクルで重複カウントしない, 仕様14/10.4）
- 進捗付与は `complete_theme_visit(verification_id, post_id)`（トランザクション）で: visited_record 作成 → **該当する全テーマ**の現在サイクルに1スロット付与（複数テーマ該当時すべて更新, 仕様10.3）。カード保存成功後にのみ呼ぶ。
- テーマ機能導入前カード・GPS/QR未検証カードは加算しない（verification 経由でしか付かないため自然に満たす, 仕様10.3）。

RLS `SELECT` 本人のみ。書き込みは関数のみ。

---

## 6. クーポン

### `coupons`
| 列 | 型 | 説明 |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK users ON DELETE CASCADE | |
| theme_id | UUID FK themes | |
| cycle_number | INTEGER | 発行時サイクル |
| reward_title | TEXT | テーマ設定のスナップショット |
| reward_description | TEXT | |
| status | TEXT CHECK in ('active','used','expired') | |
| issued_at | TIMESTAMPTZ | |
| expires_at | TIMESTAMPTZ | issued_at + 30日（仕様12.3） |
| used_at | TIMESTAMPTZ NULL | |
| idempotency_key | TEXT | 冪等キー |

- **`UNIQUE (user_id, theme_id, cycle_number)`** 重複発行防止（仕様12.2/14）
- 発行 `claim_theme_reward(theme_id)`（トランザクション）: 現在サイクルが完成（全対象店舗スロット充足）かを検証 → クーポン発行（冪等）→ **成功時のみ** 当該テーマ進捗を次サイクルへ切替（進捗行は残しつつ cycle_number を進める運用）。二重タップ/再試行で重複発行しない。
- 利用 `use_coupon(coupon_id)`（トランザクション）: active かつ未期限切れのみ used に。二重使用防止。使用済み取り消しはユーザー不可。
- 利用可能店舗は `theme_reward_stores` に従う（表示用）。
- クーポン履歴・発行済み履歴は保持（サイクルリセットで消さない, 仕様10.4/12.2）。

RLS `SELECT` 本人のみ（他人のクーポンは見えない, 仕様15）。INSERT/UPDATE 直接拒否（関数のみ）。

---

## 7. サーバー関数一覧（SECURITY DEFINER / トランザクション）

| 関数 | 役割 | 主な不変条件 |
|---|---|---|
| `are_friends(a,b)` | 友達判定ヘルパー | accepted 行の存在 |
| `send_friend_request(addressee)` | 申請 | 自己禁止/重複禁止/レート制限 |
| `respond_friend_request(id, accept)` | 承認/拒否 | addresseeのみ/pendingのみ |
| `cancel_friend_request(id)` | 取消 | requesterのみ/pendingのみ |
| `remove_friend(other)` | 解除 | accepted削除/Private権即失効 |
| `toggle_like(post_id)` | いいね | friend&非所有者&閲覧可 |
| `verify_visit(store_id,lat,lon,qr)` | 訪問確認 | GPS≤100m&QR一致をサーバー判定 |
| `complete_theme_visit(verification_id,post_id)` | 進捗付与 | 有効確認&保存後&全該当テーマ更新 |
| `claim_theme_reward(theme_id)` | クーポン発行 | サイクル完成&冪等&進捗次サイクル化 |
| `use_coupon(coupon_id)` | クーポン利用 | active&未期限&二重使用防止 |

通知生成はトリガー（`likes` INSERT, `friendships` INSERT(pending)）。

アカウント削除（Edge Function, service role, 認証フェーズで実装）:
- 本人確認後、`auth.admin.deleteUser(uid)` → `public.users` カスケードで全個人データ削除。集計保持が必要なら匿名化（MVPでは単純カスケード削除）。

---

## 8. 既存挙動への影響と注意点

- **Map探索は不変**: `get_nearby_public_cards` RPC・5km・ランダム表示ロジックは変更しない（§5.1）。ただしアプリ側 `fetchNearbyPublicCards` の既定 limit=5 → 仕様の「最大10」に合わせる軽微修正はUIフェーズで扱う（DB非変更）。
- **Private閲覧RLS変更の波及**: `private_cards` を友達閲覧可にする際、`posts` の SELECT ポリシー（現状 `deleted_at IS NULL OR 本人`）だと、友達のPrivate詳細表示に必要な `posts` 情報が取得できない可能性。友達が閲覧できるのは「友達のカードに紐づくpost」に限定するポリシー追加で対応（情報漏洩を防ぎつつ必要最小限）。実装時にクエリ経路を確認。
- **既知の潜在バグ**: `database/.../supabase_schema_update.sql` の `private_cards_location_idx` は `private_cards.location_coords` を参照するが初期スキーマに同列が無い。既存DBで適用済みかを要確認（本リニューアルでは触らないが、適用ガイドで注意喚起）。
- **論理削除トリガー**は維持。visited_records/theme_progress/coupons は post 論理削除の影響を受けない設計。

---

## 9. 適用順序（マイグレーション依存）

1. `20261017_01_profiles.sql`（users拡張・RLS・are_friends前提のusers）
2. `20261017_02_friends.sql`（friendships・are_friends・申請関数）
3. `20261017_03_likes_notifications.sql`（likes・notifications・トリガー・toggle_like）
4. `20261017_04_private_card_friend_access.sql`（private閲覧RLS更新）
5. `20261017_05_stores_themes.sql`（stores・themes・M:N）
6. `20261017_06_visits_progress.sql`（確認・記録・進捗・verify/complete関数）
7. `20261017_07_coupons.sql`（coupons・claim/use関数）

各ファイルは冪等（`IF NOT EXISTS` / `DROP POLICY IF EXISTS`）に書き、再実行可能にする。

---

## 10. 未確定・要レビュー事項

- username の変更可否（現状: 変更可とするが一意制約維持）。変更頻度制限は未実装。
- 友達申請レート制限の具体値（初期案: 同一ユーザーからの申請は10秒に1回、未承認pending総数の上限は設けない）。
- 会津コイン連携は本設計ではモック（`coupons` に reward スナップショットを保持。発行はサービス層で分離）。
- `visited_records.post_id` を必須にするか（通常訪問フローでは必ずカード保存後に記録するため NOT NULL でもよいが、将来の「保存前記録」余地を残し NULL 許容）。
- **クーポンの `expired` ステータスは利用試行時に遅延設定**。一覧表示では `status='active' AND expires_at<=now()` を期限切れ扱いにする（サーバー側ロジックで `status='active'` だけを信用しないこと）。将来は定期ジョブで一括 expire 化も可。
- **デュアルカード（公開+非公開を両方作成）の post 残存漏洩**: `08` で private専用postは友達限定にしたが、public_cardsを持つ post は全員閲覧可のままで `posts.private_image_url`・非公開コメントが読める。完全秘匿には非公開フィールドを `posts` から分離するスキーマ変更＋アプリ改修が必要（認証/投稿フェーズで方針決定）。

---

## 11. ローカル検証結果とレビュー対応

### 実施した検証（PostGIS 15 ローカルコンテナ）
既存4本 + 新規8本のマイグレーションを Supabase 相当環境（auth スキーマ/ロール/`auth.uid()`）で実地検証済み:

- **適用**: 12本すべてエラーなく適用。**再実行（冪等性）**も全てOK。
- **RLS直接書込み遮断**: friendships / likes / notifications / theme_progress / coupons / visit_verifications / theme_cycles への `authenticated` 直接INSERTはすべて拒否（関数経由のみ）。
- **QRトークン秘匿**: `store_qr_tokens` は `authenticated` から0行。`stores` は閲覧可だがハッシュを持たない。
- **公開範囲（挙動テスト）**: private専用postは owner/friend のみ閲覧可・他人は不可、publicは全員可。private_cards も friend のみ。notifications は本人のみ閲覧、`read_at` 以外の列更新は拒否。
- **コアフロー E2E**: `verify_visit`（GPS遠距離=拒否 / QR不一致=拒否 / 成立=発行）→ `complete_theme_visit`（進捗付与）→ `claim_theme_reward`（発行・重複なし・サイクル前進）→ `use_coupon`（使用→再使用拒否）まで期待どおり動作。
- `toggle_like`: 非友達=拒否 / 自分のカード=拒否 / 友達=成功＋通知生成。

### 敵対的レビューで修正した点
| ID | 内容 | 対応 |
|---|---|---|
| C6 | private情報が全員閲覧可の `posts` 経由で漏洩 | `08_posts_privacy_hardening.sql` を追加（private専用postをowner/friend限定、Map維持、ロールバック併記） |
| C5 | `notifications` UPDATEが全列改ざん可能 | `read_at` のみ列レベル許可（REVOKE UPDATE → GRANT UPDATE(read_at)） |
| M2 | `verify_visit` 再利用分岐がレート制限の後 | 再利用を先頭へ（正当な再開がレート制限に当たらない） |
| M1 | `claim` 完成判定が現 `theme_stores` 未結合 | 現対象店舗と結合して集計 |
| C3 | `claim` の `FOR UPDATE` が初回空振り | `get_current_cycle` 後にロック＋ロック後に権威サイクル再読 |
| M4 | `digest()` のsearch_pathがpgcrypto配置依存 | `verify_visit`/`set_store_qr_token` の search_path に `extensions` 追加 |

レビューで撤回された指摘（誤検知）: likes直接書込み（実際は遮断）、`ST_Point::geography`（既存RPCと同一・正常）、QRハッシュ総当り（GPSゲートで非現実的）。
