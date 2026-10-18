// クーポンのモデル。

enum CouponStatus { active, used, expired }

class Coupon {
  final String id;
  final String themeId;
  final int cycleNumber;
  final String? rewardTitle;
  final String? rewardDescription;
  final CouponStatus rawStatus;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;

  const Coupon({
    required this.id,
    required this.themeId,
    required this.cycleNumber,
    this.rewardTitle,
    this.rewardDescription,
    required this.rawStatus,
    required this.issuedAt,
    required this.expiresAt,
    this.usedAt,
  });

  /// 表示用の実効ステータス。
  /// DB上は active のままでも期限切れなら expired として扱う（遅延 expire 対策）。
  CouponStatus get effectiveStatus {
    if (rawStatus == CouponStatus.used) return CouponStatus.used;
    if (expiresAt.isBefore(DateTime.now())) return CouponStatus.expired;
    return rawStatus;
  }

  bool get isUsable => effectiveStatus == CouponStatus.active;
}
