import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coupon_models.dart';
import 'coupon_repository.dart';

/// 自分のクーポン一覧。
final myCouponsProvider = FutureProvider<List<Coupon>>((ref) {
  return ref.watch(couponRepositoryProvider).fetchMyCoupons();
});
