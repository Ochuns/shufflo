# 会津UI 画像アセット

会津らしさ（赤べこ・鶴ヶ城・会津木綿）を表現する画像をここに配置する。
画像は後日生成予定。配置したら `pubspec.yaml` の `flutter.assets` に自動で含まれる
（`assets/images/` ディレクトリ単位で登録済み）。

## 想定する画像（例）
| ファイル名（案） | 用途 |
|---|---|
| `logo.png` | アプリロゴ（赤べこモチーフ） |
| `onboarding_bg.png` | ログイン/登録画面の背景（鶴ヶ城・会津の風景） |
| `empty_cards.png` | カードが無いときの空状態イラスト |
| `empty_friends.png` | 友達がいないときの空状態イラスト |
| `theme_placeholder.png` | 未訪問店舗スロットのプレースホルダ |
| `akabeko.png` | 赤べこの装飾アイコン |

## 使い方（例）
```dart
Image.asset('assets/images/logo.png', height: 48)
```

## カラーパレット（`lib/src/theme/aizu_colors.dart`）
- 赤べこの赤: `AizuColors.akabeko` (#C5342B)
- 会津木綿の藍: `AizuColors.aizuIndigo` (#2E4A6B)
- 生成り（背景）: `AizuColors.kinari` (#F7F1E6)
画像生成時はこのパレットに調和する配色だと統一感が出る。
