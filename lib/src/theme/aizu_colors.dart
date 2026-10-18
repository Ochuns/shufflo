import 'package:flutter/material.dart';

/// 会津らしさ × モダン のカラーパレット。
/// 赤べこの赤 / 会津木綿の藍 / 温かみのある生成り を基調にしたライトテーマ用トークン。
class AizuColors {
  AizuColors._();

  // --- ベース（生成り＝温かみのある背景）---
  /// 画面全体の背景（生成り）
  static const Color kinari = Color(0xFFF7F1E6);
  /// カード・面の背景（やや白い生成り）
  static const Color surface = Color(0xFFFFFDF8);
  /// セクション区切りなどの一段沈んだ面
  static const Color surfaceAlt = Color(0xFFEFE7D6);

  // --- 赤べこ（アクセント／プライマリ）---
  static const Color akabeko = Color(0xFFC5342B); // 赤べこの赤
  static const Color akabekoDark = Color(0xFF9E2922);

  // --- 会津木綿（藍／セカンダリ）---
  static const Color aizuIndigo = Color(0xFF2E4A6B); // 会津木綿の藍
  static const Color aizuIndigoLight = Color(0xFF4A6B8F);

  // --- 文字 ---
  static const Color textPrimary = Color(0xFF2B2420); // 墨に近い焦茶
  static const Color textSecondary = Color(0xFF7A6E60); // 落ち着いた茶グレー
  static const Color textOnDark = Color(0xFFFFFDF8);

  // --- 枠線・区切り ---（墨色の約10%。const にして const ウィジェットでも使える）
  static const Color border = Color(0x1A2B2420);

  // --- 補助 ---
  static const Color gold = Color(0xFFC89B3C); // 報酬・レアリティ
  static const Color success = Color(0xFF3E7D5A);
  static const Color danger = Color(0xFFB23A2E);
}
