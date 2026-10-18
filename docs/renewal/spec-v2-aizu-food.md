# Shufflo v2 仕様書 — 会津の食ハッカソン版（差分仕様）

> この仕様書は **ゼロから作るための仕様ではなく、既存実装（develop ブランチ）への差分仕様** である。
> 各機能ブランチを担当するAIは、**まず既存コードとDBを調査し、再利用できるものは再利用**すること。
> すでに実装済みの機能を作り直さないこと（§2 の実装状況を必ず確認）。

---

## 1. コンセプト

会津で開催されるハッカソン（テーマ：**会津の食**）で使用する。
Shufflo を「**会津の飲食店と学生を『認知』の面でつなぐ、トレーディングカード型の体験記録・収集アプリ**」にする。

学生は訪れた飲食店の体験をカードとして記録・収集し、テーマ（例：会津ラーメン巡り）を達成して報酬（クーポン）を得る。友達の投稿を見て、新しい店を知る。これにより会津の飲食店の認知と来店を促す。

### 基本方針
- 既存の構造・機能・DB（RLS/RPC）を最大限再利用し、既存挙動を壊さない。
- 公開範囲・いいね可否・進捗付与・報酬などの不変条件は **サーバー側（Supabase RLS / 関数 / トリガー）** で強制する（クライアントの自己申告を信用しない）。
- UIは **日本語** を基本とし、親しみやすい **会津弁** を適度に織り交ぜる。重要情報（操作説明・エラー・権限）は正確さを優先。
- UIは **会津らしさ × モダン**（赤べこ・鶴ヶ城などのモチーフ）。使用画像は別途生成予定（本仕様では配置位置と用途のみ規定）。

---

## 2. 【最重要】現状の実装状況（develop）

| 領域 | 状態 | 実体（再利用対象） |
|---|---|---|
| 認証（登録/ログイン/メール確認/匿名移行/退会） | ✅ 実装済 | `lib/src/features/auth/`、`migration 09/10`、Edge Function `delete-account` |
| 友達（検索/申請/承認/拒否/解除/一覧/友達プロフィール） | ✅ 実装済 | `lib/src/features/social/`、`social_repository.dart`、`send/respond/cancel/remove_friend` RPC |
| タイムライン（友達限定SNS・Public/Private統合） | ✅ 実装済 | `timeline_list.dart`、`fetchTimelineCards`、`private_cards` の友達閲覧RLS |
| いいね・通知 | ✅ 実装済 | `like_action.dart`、`notifications_screen.dart`、`toggle_like` RPC、通知トリガー |
| プロフィール（動的表示・編集） | ✅ 実装済 | `profile_screen.dart`、`updateMyProfile` |
| テーマコレクション（Feed一覧・詳細・店舗スロット・報酬受取） | ✅ 実装済 | `lib/src/features/feed/`、`theme_repository.dart`、`themes/theme_stores/theme_progress`、`claim_theme_reward` RPC |
| DB全体のRLS・サーバー関数 | ✅ 実装済 | `supabase/migrations/20261017*` |
| **会津UI・既存画面の日本語化・会津弁** | ❌ 未実装 | → `feature/aizu-ui` |
| **Mapの絞り込み・飲食カテゴリ特化** | ❌ 未実装 | → `feature/map-food-filter` |
| **GPS+QR訪問確認（テーマ進捗の発生源）** | ❌ 未実装（DBは実装済） | → `feature/visit-verification` |
| **クーポン一覧/利用UI** | ❌ 未実装（発行DBは実装済） | → `feature/coupons-ui` |

> つまり本仕様で新規実装するのは **4ブランチ分** のみ。Feed/Profile/認証/友達は「作り直さず、仕上げ・微調整」。

---

## 3. ブランチ構成

| ブランチ | 担当 | 種別 |
|---|---|---|
| `feature/aizu-ui` | 会津らしいデザイン・ライトモード化・全画面の日本語化・会津弁 | 大半が新規（全画面リスタイル） |
| `feature/map-food-filter` | Map の絞り込み（飲食カテゴリ）＋カテゴリの飲食特化 | 新規 |
| `feature/visit-verification` | GPS+QR 訪問確認 → 撮影 → カード作成 → テーマ進捗更新 | 新規（DB・RPCは実装済） |
| `feature/coupons-ui` | クーポン一覧・利用（Profileから） | 新規（発行DB・RPCは実装済） |

統合先は `develop`。基盤に近いもの（visit-verification）を先に、UIリスタイル（aizu-ui）は内容が固まった後半に統合するのが安全。

---

## 4. 機能別 差分仕様

### 4.1 `feature/aizu-ui` — 会津UI・日本語化・会津弁

**目的**: 「会津の食」らしい世界観に統一し、全UIを日本語化する。

**デザインコンセプト（会津らしさ × モダン）**
- **ライトモード固定**（現状はダークテーマ `AppTheme.darkTheme`。ライトテーマへ全面変更）。
- カラーパレット:
  - 赤べこの赤（アクセント）
  - 会津木綿の藍色
  - 温かみのある生成り色（背景）
- 伝統モチーフ（赤べこ・鶴ヶ城）は**控えめ**に。飲食店やカードの写真を主役に。
- 既存のトレーディングカードらしさ・レアリティ表現は維持。
- **使用画像**（ロゴ、空状態イラスト、オンボーディング背景、赤べこ/鶴ヶ城モチーフ等）は後日生成。本ブランチでは `assets/images/` に配置する前提でプレースホルダを置き、`pubspec.yaml` の assets 登録まで行う。

**日本語化（必須）**
- 既存画面に残る英語をすべて日本語化する。特に:
  - Map/Explore（`explore_screen.dart`、`card_detail_screen.dart` の "Pin Card"/"Unpin"/"View in Deck" 等）
  - Post（`post_screen.dart`）
  - My Cards（`my_cards_screen.dart`、デッキ関連）
  - 共通ウィジェット（ボタン文言等）
- 新画面（認証/友達/テーマ）は日本語済だが、トーンを統一する。

**会津弁（理想）**
- 親しみやすいカジュアル文（空状態・成功トースト・見出し補助）に適度に会津弁を使う。
  - 例（実装済の一部）: 「まだ投稿がねぇな」「見つからねぇな」「報酬を受け取ったぞ！」
- **重要情報は標準語で正確に**: 認証エラー、権限エラー、操作手順、課金/クーポン関連。
- 会津弁の表現は、可能なら地域の話者に自然さを確認してもらうことが望ましい。

**やること**
- `app_theme.dart` をライト+会津カラーに刷新（Material3、`Brightness.light`）。
- 各画面のハードコード色（`Colors.black`/`0xFF141414` 等のダーク値）を新テーマトークンに置換。
- 文言の日本語化・会津弁反映。
- `assets/images/` 構成＋プレースホルダ＋`pubspec.yaml` 登録。

**やらないこと / 注意**
- 画面の機能・導線は変えない（見た目と文言のみ）。
- Map の探索挙動・カード作成フロー・デッキは壊さない。

---

### 4.2 `feature/map-food-filter` — Map絞り込み＋飲食カテゴリ特化

**目的**: 「会津の食」に合わせ、Map をカテゴリで絞り込めるようにし、カテゴリを飲食中心に絞る。

**カテゴリの飲食特化**
- 現状のカテゴリは `ExperienceCategory { restaurant, cafe, sightseeing, amusement, other }`（`experience_card_model.dart`）。
- 今回は **restaurant（飲食店）/ cafe（カフェ）の2つ** を基本とする。
- 方針（推奨・要確定）:
  - **カード作成（Post）** の選択肢を restaurant / cafe の2つに限定する。
  - enum は**残したまま**UIの選択肢だけを絞る（既存の sightseeing 等のカードが壊れないように）。将来の拡張余地も残る。
  - 表示ラベルは日本語（「飲食店」「カフェ」）。`ExperienceCategoryExtension.label` を調整。

**Map の絞り込み**
- Map（`explore_screen.dart`）に **カテゴリ絞り込みUI**（例: 上部に「すべて / 飲食店 / カフェ」のチップ）を追加。
- 既存挙動は維持: 現在地から半径5km・最大10枚のPublicカードをレーダー的に表示（`get_nearby_public_cards` RPC）。
- 絞り込みの実装方針（どちらか／要検討）:
  - **A案（推奨）**: RPC `get_nearby_public_cards` に任意の `category` 引数を追加し、サーバー側で絞ってから近い順・件数制限。空間インデックスを活かせる。マイグレーション追加。
  - **B案（簡易）**: RPCは現状のまま、返ってきたカードをクライアント側でカテゴリ絞り込み。実装は軽いが、10件制限と相性が悪い（絞ると表示が少なくなる）。
- 位置情報が取れない場合の扱い: 既存の「渋谷駅フォールバック」(`post_screen.dart`) は会津向けに不適。**架空現在地を実在として扱わず**、「位置情報を取得できません」旨を明示する挙動へ改善（初版仕様 §5.1 と同方針）。

**やらないこと**
- テーマ専用の店舗表示や訪問済みマーカーは Map に追加しない（Map はあくまで近くのPublicカード探索）。

---

### 4.3 `feature/visit-verification` — GPS+QR訪問確認（テーマ進捗の要）

**目的**: テーマコレクション（Feed）の進捗を**実際に発生させる**仕組み。ユーザーのご不安（「ラーメン屋をどう絞るか／条件判定／位置情報」）は **DB側で設計済み**。本ブランチは **Flutter側のフロー** を実装する。

**設計の前提（すでにDBに実装済み — 再利用）**
- **店舗の判定は固定の店舗ID**で行う（`theme_stores` に「このテーマの対象店舗ID」を登録）。店名の曖昧一致やAI推測は使わない。
- **訪問の成立は GPS + QR の両方**で判定（`verify_visit` RPC）:
  - GPS: サーバー側で店舗位置から **100m以内** か判定（PostGIS、クライアントの距離判定を信用しない）。
  - QR: 店舗ごとの固定QRのトークンを**ハッシュ照合**して店舗IDを解決（平文はDBに保存しない）。
- 訪問確認は **24時間有効**。カード保存成功後に `complete_theme_visit` RPC が訪問記録を作り、**該当する全テーマの現サイクルに進捗を1つ付与**。同一店舗の重複カウントは不可。

**実装するフロー（Flutter）**
1. テーマ詳細 or 専用導線から「この店で記録する」→ **訪問確認画面**を開く。
2. GPS位置を取得（既存 `location_provider.dart` を再利用）。
3. **店舗の固定QRをスキャン**（新規パッケージ: 例 `mobile_scanner`）。
4. `verify_visit(store_id, lat, lon, qr_token)` を呼ぶ → 成立すると確認状態（verification_id）が返る。
5. **アプリ内カメラで現地写真を撮影**（`image_picker` の `ImageSource.camera`。ギャラリー選択だけでは進捗を獲得させない）。撮り直し可。
6. 撮影後、**既存の Create 画面（`post_screen.dart`）を開き、店舗情報と撮影写真を自動入力**。ユーザーは通常のカード作成項目を入力。
7. 保存成功後に `complete_theme_visit(verification_id, post_id)` を呼び、訪問記録＋テーマ進捗を更新。
8. 中断・再開: 確認状態は24h保持。期限内なら再開可。キャンセルしても即削除しない。カード保存成功まで進捗は増えない。

**新規パッケージ（要追加）**
- QRスキャン: `mobile_scanner`（推奨）等。
- カメラ: 既存 `image_picker`（camera source）で可。本格的なアプリ内カメラが必要なら `camera`。
- iOS/Android の権限（カメラ・位置情報）の Info.plist / AndroidManifest 追記。

**検証の注意**
- QR/カメラ/GPS は **実機でないと検証不可**。シミュレータはGPSモック・QRは画像読取で部分確認。
- `verify_visit`/`complete_theme_visit` のサーバー側ロジックはローカルPostGISで検証済み（GPS遠=拒否 / QR不一致=拒否 / 二重防止）。

**店舗・テーマ・QRの登録（運用）**
- 管理UIは作らない。SQLで `stores` / `store_qr_tokens`（`set_store_qr_token` で平文→ハッシュ登録）/ `themes` / `theme_stores` / `theme_reward_stores` を登録（`apply-guide.md §3` 参照）。
- QRコードには `set_store_qr_token` に渡した平文トークンを埋め込む。

---

### 4.4 `feature/coupons-ui` — クーポン一覧・利用

**目的**: 報酬（クーポン）の一覧・利用UI。発行ロジック（`claim_theme_reward`）と `coupons` テーブルは実装済み。

**仕様（DBは実装済み。UIを作る）**
- Profile に「クーポン一覧」導線を追加（§5.5）。
- クーポン一覧画面: 有効 / 使用済み / 期限切れ を区別して表示。
  - 期限切れ判定: `status='active' AND expires_at <= now()` も期限切れ扱い（`expired` は遅延設定のため）。
- 「クーポンを使う」→ 確認ダイアログ → `use_coupon(coupon_id)` → 使用済みに。二重使用はサーバーが防止。使用済みの取り消しはユーザー不可。
- 有効期限は発行から30日（DB側で設定済み）。利用可能店舗は `theme_reward_stores`（表示用）。
- 会津コイン等の外部連携は本番ではモック（発行は固定特典）。将来連携を見越し発行はサービス層に分離済み。

---

## 5. 既存資産（再利用必須）

**DB（`supabase/migrations/20261017*`）**: `users`(拡張) / `friendships` / `likes` / `notifications` / `stores` / `store_qr_tokens` / `themes` / `theme_stores` / `theme_reward_stores` / `visit_verifications` / `visited_records` / `theme_cycles` / `theme_progress` / `coupons`。

**主なRPC**: `is_username_available` / `send_friend_request` / `respond_friend_request` / `cancel_friend_request` / `remove_friend` / `are_friends` / `toggle_like` / `verify_visit` / `complete_theme_visit` / `claim_theme_reward` / `use_coupon` / `get_nearby_public_cards`。

**Flutter**: `lib/src/features/{auth,social,feed,explore,my_cards,post,profile}`、`lib/src/models/{supabase_repository,social_*,theme_*}.dart`、`lib/src/common_widgets/`、`app_router.dart`（`redirect` 認証ゲート付き）、`app_theme.dart`。

**設計資料**: `docs/renewal/db-design.md` / `auth-flow.md` / `apply-guide.md`。

---

## 6. 未確定・要検討

- **カテゴリ縮小の方針**: enum残置＋UI限定（推奨）か、enum自体を縮小（既存データ移行が必要）か。→ 推奨は残置。
- **Map絞り込み**: RPC拡張（A案）か クライアント絞り込み（B案）か。→ 推奨はA案。
- **訪問確認の導線**: テーマ詳細の店舗スロットから開くか、専用タブ/ボタンか。
- **QRスキャナ/カメラのパッケージ選定**と権限設定。
- **会津弁の監修**（地域話者による自然さ確認）。
- **生成画像の点数・用途**（ロゴ/空状態/モチーフ/オンボーディング）。

---

## 7. 各AI（実装者）への指示

各ブランチで必ず:
1. 変更前の既存挙動・既存コード・DBを調査する（本書 §2/§5）。
2. 変更対象と影響範囲を明示する。
3. 小さな単位で実装し、`flutter analyze` をエラー0に保つ。
4. DB変更があればマイグレーションを用意（**14桁タイムスタンプ命名**。`20261017_01` のような重複版は不可）。
5. RLS/サーバー整合性を尊重（公開範囲・付与可否はサーバー側で強制）。
6. 既存機能（Map探索・カード作成・デッキ・認証・友達）を壊していないか確認。
7. 実施した変更・テスト結果・未対応事項を報告する。

**完成条件**: 会津の食テーマのUI/日本語で、認証・友達SNS・テーマ収集（GPS+QR訪問で進捗）・クーポンが一貫して動作し、既存のMap/カード作成/デッキを壊していないこと。
