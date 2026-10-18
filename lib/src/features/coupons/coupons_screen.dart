import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/coupon_models.dart';
import '../../models/coupon_providers.dart';
import '../../models/coupon_repository.dart';

/// クーポン一覧（Profileから開く, §12.3）。
/// 有効 / 使用済み / 期限切れ を区別して表示し、有効なものは利用できる。
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCouponsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('クーポン')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('読み込みに失敗しました')),
        data: (coupons) {
          if (coupons.isEmpty) {
            return const Center(
              child: Text('まだクーポンはねぇな\nテーマを達成してゲットしてけさい',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myCouponsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CouponCard(coupon: coupons[i]),
            ),
          );
        },
      ),
    );
  }
}

class _CouponCard extends ConsumerStatefulWidget {
  const _CouponCard({required this.coupon});
  final Coupon coupon;

  @override
  ConsumerState<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends ConsumerState<_CouponCard> {
  bool _using = false;

  Future<void> _use() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('クーポンを使いますか？'),
        content: const Text('使用済みにすると元に戻せません。店員さんに見せる直前に押してけさい。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('使う')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _using = true);
    try {
      await ref.read(couponRepositoryProvider).useCoupon(widget.coupon.id);
      ref.invalidate(myCouponsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('クーポンを使用しました')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('使用に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _using = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final status = c.effectiveStatus;
    final dim = status != CouponStatus.active;
    final df = DateFormat('yyyy/MM/dd');

    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == CouponStatus.active
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.local_activity, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.rewardTitle ?? '特典',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                              ),
                            ),
                            _StatusBadge(status: status),
                          ],
                        ),
                        if (c.rewardDescription != null && c.rewardDescription!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(c.rewardDescription!,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ],
                        const SizedBox(height: 8),
                        Text('有効期限: ${df.format(c.expiresAt)}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (status == CouponStatus.active)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: _using ? null : _use,
                    icon: _using
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.redeem),
                    label: const Text('クーポンを使う'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final CouponStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (status) {
      case CouponStatus.active:
        label = '有効';
        color = Colors.green;
        break;
      case CouponStatus.used:
        label = '使用済み';
        color = Colors.grey;
        break;
      case CouponStatus.expired:
        label = '期限切れ';
        color = Colors.redAccent;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
