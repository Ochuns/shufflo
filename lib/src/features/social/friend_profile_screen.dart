import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/social_models.dart';
import '../../models/social_providers.dart';
import '../../models/social_repository.dart';
import 'timeline_list.dart';

/// 他ユーザーのプロフィール（§8.4）＋タイムライン。
/// 友達申請の通知からも開かれ、保留中の申請をここで承認/拒否できる（§9.2）。
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final relationAsync = ref.watch(relationProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(profileAsync.value?.username ?? 'プロフィール'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('プロフィールを読み込めませんでした')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('ユーザーが見つかりません'));
          }
          return Column(
            children: [
              _Header(
                profile: profile,
                relationInfo: relationAsync.value,
                onChanged: () {
                  ref.invalidate(relationProvider(userId));
                  ref.invalidate(friendsProvider);
                  ref.invalidate(timelineProvider(userId));
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                },
              ),
              const Divider(height: 1),
              Expanded(child: TimelineList(userId: userId)),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.profile, required this.relationInfo, required this.onChanged});
  final UserProfile profile;
  final FriendRelationInfo? relationInfo;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  bool _working = false;

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('友達を解除しますか？'),
        content: const Text('解除すると相手のPrivateカードは見られなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('解除')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repo.removeFriend(widget.profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(radius: 40, backgroundImage: CachedNetworkImageProvider(p.displayAvatar)),
          const SizedBox(height: 12),
          Text(p.username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.bio!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
          ],
          const SizedBox(height: 8),
          Text('投稿 ${p.postCount}', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          if (_working)
            const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))
          else
            _buildAction(),
        ],
      ),
    );
  }

  Widget _buildAction() {
    final info = widget.relationInfo;
    if (info == null) return const SizedBox(height: 40);
    switch (info.relation) {
      case FriendRelation.self:
        return const SizedBox.shrink();
      case FriendRelation.friends:
        return OutlinedButton.icon(
          onPressed: _confirmRemove,
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('友達を解除'),
        );
      case FriendRelation.pendingOutgoing:
        return OutlinedButton(
          onPressed: () => _run(() => _repo.cancelFriendRequest(info.friendshipId!)),
          child: const Text('申請中・取り消す'),
        );
      case FriendRelation.pendingIncoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () => _run(() => _repo.respondFriendRequest(info.friendshipId!, true)),
              child: const Text('承認する'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _run(() => _repo.respondFriendRequest(info.friendshipId!, false)),
              child: const Text('拒否'),
            ),
          ],
        );
      case FriendRelation.none:
        return FilledButton.icon(
          onPressed: () => _run(() => _repo.sendFriendRequest(widget.profile.id)),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('友達申請'),
        );
    }
  }
}
