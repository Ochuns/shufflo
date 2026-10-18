import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coupon_models.dart';

final couponRepositoryProvider = Provider((ref) => CouponRepository());

/// クーポンのデータ層。発行(claim)はテーマ詳細側、ここでは一覧・利用を扱う。
/// 発行・使用状態の整合性はサーバー側（RLS/関数）で強制される。
class CouponRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Coupon>> fetchMyCoupons() async {
    final me = currentUserId;
    if (me == null) return [];
    final List rows = await _supabase
        .from('coupons')
        .select(
          'id, theme_id, cycle_number, reward_title, reward_description, '
          'status, issued_at, expires_at, used_at',
        )
        .eq('user_id', me)
        .order('issued_at', ascending: false);

    return rows.map<Coupon>((r) {
      return Coupon(
        id: r['id'],
        themeId: r['theme_id'],
        cycleNumber: r['cycle_number'] ?? 1,
        rewardTitle: r['reward_title'],
        rewardDescription: r['reward_description'],
        rawStatus: _parseStatus(r['status']),
        issuedAt: DateTime.parse(r['issued_at']).toLocal(),
        expiresAt: DateTime.parse(r['expires_at']).toLocal(),
        usedAt: r['used_at'] != null ? DateTime.parse(r['used_at']).toLocal() : null,
      );
    }).toList();
  }

  /// クーポンを使用する（active かつ未期限のみ。二重使用はサーバーが防止）。
  Future<void> useCoupon(String couponId) async {
    await _supabase.rpc('use_coupon', params: {'p_coupon_id': couponId});
  }

  CouponStatus _parseStatus(String? s) {
    switch (s) {
      case 'used':
        return CouponStatus.used;
      case 'expired':
        return CouponStatus.expired;
      default:
        return CouponStatus.active;
    }
  }
}
