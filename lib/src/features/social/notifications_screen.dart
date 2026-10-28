import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../models/social_providers.dart';
import '../../models/social_repository.dart';
import '../../models/cards_provider.dart';
import '../../utils/relative_time.dart';

/// 通知一覧（いいね / 友達申請のみ, §9.2）。
/// 開いた（タップした）通知だけを既読にする。
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('読み込みに失敗しました')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('通知はありません', style: TextStyle(color: Colors.grey)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _NotificationTile(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(socialRepositoryProvider);
    if (!item.isRead) {
      try {
        await repo.markRead(item.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } catch (_) {
        /* 既読化失敗は致命的でないため無視 */
      }
    }
    if (!context.mounted) return;

    if (item.type == NotificationType.friendRequest) {
      // 相手のプロフィールで承認/拒否
      context.push('/user', extra: item.actorId);
    } else {
      // いいね → 対象カード詳細へ（自分のカードのため cardsProvider から解決）
      final cards = ref.read(cardsProvider).value ?? const [];
      final match = cards.where((c) => c.postId == item.postId).toList();
      if (match.isNotEmpty) {
        context.push('/card_detail', extra: match.first);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('対象のカードが見つかりませんでした')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLike = item.type == NotificationType.like;
    return Container(
      color: item.isRead ? null : Colors.blueAccent.withValues(alpha: 0.08),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(
                (item.actorAvatarUrl != null && item.actorAvatarUrl!.isNotEmpty)
                    ? item.actorAvatarUrl!
                    : 'https://i.pravatar.cc/300',
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: isLike ? Colors.pinkAccent : Colors.blueAccent,
                child: Icon(
                  isLike ? Icons.favorite : Icons.person_add_alt_1,
                  size: 11,
                  color: AizuColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: item.actorUsername,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: isLike ? ' さんがカードにいいねしました' : ' さんから友達申請が届きました'),
            ],
          ),
        ),
        subtitle: Text(relativeTime(item.createdAt)),
        trailing: item.isRead
            ? null
            : const Icon(Icons.circle, size: 10, color: Colors.blueAccent),
        onTap: () => _handleTap(context, ref),
      ),
    );
  }
}
