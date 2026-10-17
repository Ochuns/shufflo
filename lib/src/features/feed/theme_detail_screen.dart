import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/theme_models.dart';
import '../../models/theme_providers.dart';
import '../../models/theme_repository.dart';

/// テーマ詳細（§10.2）。店舗スロット・進捗・報酬・受け取りボタン（完成時のみ）。
class ThemeDetailScreen extends ConsumerWidget {
  const ThemeDetailScreen({super.key, required this.themeId});
  final String themeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(themeDetailProvider(themeId));
    return Scaffold(
      appBar: AppBar(title: Text(async.value?.summary.name ?? 'テーマ')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('読み込みに失敗しました')),
        data: (detail) => _Body(detail: detail, themeId: themeId),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.detail, required this.themeId});
  final ThemeDetail detail;
  final String themeId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      await ref.read(themeRepositoryProvider).claimReward(widget.themeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('報酬を受け取ったぞ！クーポンを確認してけさい')),
      );
      ref.invalidate(themeDetailProvider(widget.themeId));
      ref.invalidate(themesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報酬の受け取りに失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.detail.summary;
    final slots = widget.detail.slots;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 進捗
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                      s.isComplete ? Colors.amber : Colors.pinkAccent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${s.collectedCount} / ${s.targetCount}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 20),
        // 店舗スロット
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: slots.length,
          itemBuilder: (_, i) => _SlotTile(slot: slots[i]),
        ),
        const SizedBox(height: 24),
        // 報酬
        if (s.rewardTitle != null && s.rewardTitle!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.rewardTitle!,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.amber)),
                      if (s.rewardDescription != null && s.rewardDescription!.isNotEmpty)
                        Text(s.rewardDescription!,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // 受け取りボタン（完成時のみ）
        if (s.isComplete)
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: _claiming ? null : _claim,
            icon: _claiming
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.redeem),
            label: const Text('報酬を受け取る'),
          ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot});
  final ThemeStoreSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: slot.visited
              ? Colors.pinkAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: slot.visited ? _visitedImage() : _placeholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              slot.storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: slot.visited ? Colors.white : Colors.grey.shade500,
                fontSize: 13,
                fontWeight: slot.visited ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitedImage() {
    final local = slot.cardLocalPath;
    if (local != null && File(local).existsSync()) {
      return Image.file(File(local), fit: BoxFit.cover, width: double.infinity);
    }
    if (slot.cardImageUrl != null && slot.cardImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: slot.cardImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, _) => Container(color: const Color(0xFF1E1E1E)),
        errorWidget: (_, _, _) => _placeholder(),
      );
    }
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(child: Icon(Icons.check_circle, color: Colors.pinkAccent)),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(Icons.location_on_outlined, color: Colors.grey.shade700, size: 32),
      ),
    );
  }
}
