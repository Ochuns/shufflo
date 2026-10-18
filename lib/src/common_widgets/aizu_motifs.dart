import 'package:flutter/material.dart';
import '../theme/aizu_colors.dart';

/// 赤べこ（会津の郷土玩具・赤い牛）を簡易に描くアイコン。
/// 画像アセットが用意できるまでのプレースホルダとしても使える。
class AkabekoIcon extends StatelessWidget {
  const AkabekoIcon({super.key, this.size = 40, this.color = AizuColors.akabeko});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AkabekoPainter(color)),
    );
  }
}

class _AkabekoPainter extends CustomPainter {
  _AkabekoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final black = Paint()..color = const Color(0xFF2B2420);
    final white = Paint()..color = const Color(0xFFFFFDF8);

    // 胴体（丸みのある台形）
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.40, w * 0.56, h * 0.34),
        Radius.circular(h * 0.16),
      ));
    canvas.drawPath(bodyPath, body);

    // 首〜頭
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.30, w * 0.26, h * 0.26),
        Radius.circular(h * 0.10),
      ),
      body,
    );
    // 頭
    canvas.drawCircle(Offset(w * 0.80, h * 0.34), h * 0.15, body);

    // 脚
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.70, w * 0.08, h * 0.16), body);
    canvas.drawRect(Rect.fromLTWH(w * 0.60, h * 0.70, w * 0.08, h * 0.16), body);

    // 背中の白斑点（赤べこらしさ）
    canvas.drawCircle(Offset(w * 0.40, h * 0.52), h * 0.045, white);
    canvas.drawCircle(Offset(w * 0.52, h * 0.58), h * 0.04, white);
    canvas.drawCircle(Offset(w * 0.46, h * 0.46), h * 0.035, white);

    // 目
    canvas.drawCircle(Offset(w * 0.84, h * 0.32), h * 0.025, black);
    // 角
    final horn = Path()
      ..moveTo(w * 0.76, h * 0.22)
      ..lineTo(w * 0.80, h * 0.12)
      ..lineTo(w * 0.84, h * 0.22)
      ..close();
    canvas.drawPath(horn, black);
  }

  @override
  bool shouldRepaint(covariant _AkabekoPainter old) => old.color != color;
}

/// 鶴ヶ城（会津のシンボル）を簡易に描くアイコン（天守のシルエット）。
class TsurugajoIcon extends StatelessWidget {
  const TsurugajoIcon({super.key, this.size = 40, this.color = AizuColors.aizuIndigo});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CastlePainter(color)),
    );
  }
}

class _CastlePainter extends CustomPainter {
  _CastlePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final roof = Paint()..color = const Color(0xFFB03A32); // 鶴ヶ城の赤瓦

    // 石垣（台形の土台）
    final base = Path()
      ..moveTo(w * 0.12, h * 0.92)
      ..lineTo(w * 0.22, h * 0.70)
      ..lineTo(w * 0.78, h * 0.70)
      ..lineTo(w * 0.88, h * 0.92)
      ..close();
    canvas.drawPath(base, p);

    // 天守（3層）を上に積む
    void tier(double top, double left, double right, double bottom) {
      canvas.drawRect(Rect.fromLTRB(w * left, h * top, w * right, h * bottom), p);
      // 赤瓦の屋根（横に少し張り出す三角帯）
      final r = Path()
        ..moveTo(w * (left - 0.04), h * top)
        ..lineTo(w * (left + right) / 2, h * (top - 0.08))
        ..lineTo(w * (right + 0.04), h * top)
        ..close();
      canvas.drawPath(r, roof);
    }

    tier(0.60, 0.30, 0.70, 0.70); // 下層
    tier(0.42, 0.36, 0.64, 0.60); // 中層
    tier(0.24, 0.42, 0.58, 0.42); // 上層（最上）
    // 最上の屋根
    final topRoof = Path()
      ..moveTo(w * 0.38, h * 0.24)
      ..lineTo(w * 0.50, h * 0.14)
      ..lineTo(w * 0.62, h * 0.24)
      ..close();
    canvas.drawPath(topRoof, roof);
  }

  @override
  bool shouldRepaint(covariant _CastlePainter old) => old.color != color;
}
