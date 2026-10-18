import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../models/social_providers.dart';

/// カード詳細のいいねアクション。
/// - 自分のカード: いいね数を表示し、タップでいいねしたユーザー一覧（§9.1）
/// - 友達のカード: いいねトグル
/// - それ以外（非友達）: 非表示（付与可否の最終判定はサーバーの toggle_like）
class LikeAction extends ConsumerWidget {
  const LikeAction({
    super.key,
    required this.postId,
    required this.authorId,
    required this.isOwner,
  });

  final String? postId;
  final String authorId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pid = postId;
    if (pid == null) return const SizedBox.shrink();

    if (isOwner) {
      final count = ref.watch(likeCountProvider(pid));
      return TextButton.icon(
        onPressed: () => _showLikers(context, ref, pid),
        icon: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 20),
        label: Text('${count.value ?? 0}',
            style: const TextStyle(color: AizuColors.textPrimary)),
      );
    }

    final relation = ref.watch(relationProvider(authorId));
    final isFriend = relation.value?.relation == FriendRelation.friends;
    if (!isFriend) return const SizedBox.shrink();

    final likedAsync = ref.watch(myLikedPostIdsProvider);
    final liked = likedAsync.value?.contains(pid) ?? false;
    return IconButton(
      icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? Colors.pinkAccent : Colors.white),
      tooltip: liked ? 'いいね解除' : 'いいね',
      onPressed: likedAsync.hasValue
          ? () async {
              final ok = await ref.read(myLikedPostIdsProvider.notifier).toggle(pid);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('いいねに失敗しました')));
              }
            }
          : null,
    );
  }

  void _showLikers(BuildContext context, WidgetRef ref, String pid) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AizuColors.surface,
      builder: (_) => Consumer(
        builder: (c, r, _) {
          final likers = r.watch(likersProvider(pid));
          return SafeArea(
            child: likers.when(
              loading: () => const SizedBox(
                  height: 140, child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const SizedBox(
                  height: 140, child: Center(child: Text('読み込みに失敗しました'))),
              data: (list) => list.isEmpty
                  ? const SizedBox(
                      height: 140,
                      child: Center(
                          child: Text('まだいいねはありません',
                              style: TextStyle(color: Colors.grey))))
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('いいねしたユーザー',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        ...list.map((u) => ListTile(
                              leading: CircleAvatar(
                                  backgroundImage:
                                      CachedNetworkImageProvider(u.displayAvatar)),
                              title: Text(u.username),
                              onTap: () {
                                Navigator.pop(c);
                                context.push('/user', extra: u.id);
                              },
                            )),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
