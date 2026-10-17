import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_providers.dart';

/// 友達一覧（友達になった日時の新しい順, §8.3）。
class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('友達'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'ユーザーを探す',
            onPressed: () => context.push('/user_search'),
          ),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('読み込みに失敗しました')),
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('まだ友達がいねぇな', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/user_search'),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('ユーザーを探す'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(friendsProvider),
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (_, i) {
                final f = friends[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(f.profile.displayAvatar),
                  ),
                  title: Text(f.profile.username),
                  subtitle: f.profile.bio != null && f.profile.bio!.isNotEmpty
                      ? Text(f.profile.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: () => context.push('/user', extra: f.profile.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
