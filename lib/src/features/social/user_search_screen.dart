import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../models/social_providers.dart';
import '../../models/social_repository.dart';

/// ユーザー検索（ユーザー名の部分一致）。自分は除外。
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(userSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'ユーザー名で探す',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text('ユーザー名を入力してけさい', style: TextStyle(color: Colors.grey)))
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('検索に失敗しました')),
              data: (results) {
                if (results.isEmpty) {
                  return const Center(child: Text('見つからねぇな', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => _UserTile(result: results[i], onChanged: () {
                    ref.invalidate(userSearchProvider(_query));
                    ref.invalidate(friendsProvider);
                  }),
                );
              },
            ),
    );
  }
}

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.result, required this.onChanged});
  final UserSearchResult result;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _working = false;

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(r.profile.displayAvatar),
      ),
      title: Text(r.profile.username),
      subtitle: r.profile.bio != null && r.profile.bio!.isNotEmpty
          ? Text(r.profile.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: _working
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : _buildAction(r),
      onTap: () => context.push('/user', extra: r.profile.id),
    );
  }

  Widget _buildAction(UserSearchResult r) {
    switch (r.relation) {
      case FriendRelation.friends:
        return const Chip(label: Text('友達'));
      case FriendRelation.pendingOutgoing:
        return TextButton(
          onPressed: () => _run(() => _repo.cancelFriendRequest(r.friendshipId!)),
          child: const Text('申請中・取消'),
        );
      case FriendRelation.pendingIncoming:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _run(() => _repo.respondFriendRequest(r.friendshipId!, true)),
              child: const Text('承認'),
            ),
            TextButton(
              onPressed: () => _run(() => _repo.respondFriendRequest(r.friendshipId!, false)),
              child: const Text('拒否'),
            ),
          ],
        );
      case FriendRelation.none:
        return FilledButton(
          onPressed: () => _run(() => _repo.sendFriendRequest(r.profile.id)),
          child: const Text('申請'),
        );
      case FriendRelation.self:
        return const SizedBox.shrink();
    }
  }
}
