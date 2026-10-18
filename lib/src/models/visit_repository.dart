import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final visitRepositoryProvider = Provider((ref) => VisitRepository());

/// GPS+QR 訪問確認のデータ層。
/// 距離判定(100m)・QRトークン照合・24h有効性はすべてサーバー側(verify_visit)で行う。
/// クライアントは座標とスキャンしたトークンを渡すだけで、判定結果を自己申告しない。
class VisitRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 訪問確認を発行する。成立すると verification_id を返す。
  /// 失敗（GPS遠い/QR不一致/非対象店舗）はサーバーが例外を投げる。
  Future<String> verifyVisit({
    required String storeId,
    required double lat,
    required double lon,
    required String qrToken,
  }) async {
    final res = await _supabase.rpc('verify_visit', params: {
      'p_store_id': storeId,
      'p_lat': lat,
      'p_lon': lon,
      'p_qr_token': qrToken,
    });
    // verify_visit は visit_verifications 行(Map)を返す
    if (res is Map && res['id'] != null) return res['id'] as String;
    if (res is List && res.isNotEmpty && res.first['id'] != null) {
      return res.first['id'] as String;
    }
    throw Exception('訪問確認に失敗しました');
  }

  /// カード保存成功後に呼び、訪問記録＋該当テーマの進捗を更新する。
  Future<void> completeThemeVisit({
    required String verificationId,
    required String postId,
  }) async {
    await _supabase.rpc('complete_theme_visit', params: {
      'p_verification_id': verificationId,
      'p_post_id': postId,
    });
  }
}
