import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_models.dart';

final socialRepositoryProvider = Provider((ref) => SocialRepository());

/// 友達・いいね・通知のデータ層。
/// 付与可否や状態遷移などの不変条件はサーバー側（RLS / 関数 / トリガー）で強制される。
class SocialRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // --- プロフィール ---

  Future<UserProfile?> fetchUserProfile(String userId) async {
    final row = await _supabase
        .from('users')
        .select('id, username, avatar_url, bio')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final posts = await _supabase
        .from('posts')
        .select('id')
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
    return UserProfile(
      id: row['id'],
      username: row['username'] ?? '',
      avatarUrl: row['avatar_url'],
      bio: row['bio'],
      postCount: (posts as List).length,
    );
  }

  /// プロフィール編集（本人のみ。UNIQUE違反は AuthException/PostgrestException で伝わる）。
  Future<void> updateMyProfile({String? username, String? bio, String? avatarUrl}) async {
    final me = currentUserId;
    if (me == null) throw StateError('not signed in');
    final payload = <String, dynamic>{};
    if (username != null) payload['username'] = username.trim();
    if (bio != null) payload['bio'] = bio.trim();
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl.trim();
    if (payload.isEmpty) return;
    await _supabase.from('users').update(payload).eq('id', me);
  }

  // --- ユーザー検索 / 関係 ---

  Future<List<UserSearchResult>> searchUsers(String query, {int limit = 20, int offset = 0}) async {
    final me = currentUserId;
    final rows = await _supabase
        .from('users')
        .select('id, username, avatar_url, bio')
        .ilike('username', '%${query.trim()}%')
        .neq('id', me ?? '00000000-0000-0000-0000-000000000000')
        .order('username')
        .range(offset, offset + limit - 1);

    final List friRows = me == null
        ? const []
        : await _supabase
            .from('friendships')
            .select('id, requester_id, addressee_id, status')
            .or('requester_id.eq.$me,addressee_id.eq.$me');

    return (rows as List).map<UserSearchResult>((r) {
      final uid = r['id'];
      var rel = FriendRelation.none;
      String? fid;
      for (final f in friRows) {
        final req = f['requester_id'];
        final add = f['addressee_id'];
        if ((req == me && add == uid) || (req == uid && add == me)) {
          fid = f['id'];
          if (f['status'] == 'accepted') {
            rel = FriendRelation.friends;
          } else if (req == me) {
            rel = FriendRelation.pendingOutgoing;
          } else {
            rel = FriendRelation.pendingIncoming;
          }
          break;
        }
      }
      return UserSearchResult(
        profile: UserProfile(
          id: uid,
          username: r['username'] ?? '',
          avatarUrl: r['avatar_url'],
          bio: r['bio'],
        ),
        relation: rel,
        friendshipId: fid,
      );
    }).toList();
  }

  Future<FriendRelationInfo> fetchRelation(String userId) async {
    final me = currentUserId;
    if (me == null) return const FriendRelationInfo(FriendRelation.none, null);
    if (me == userId) return const FriendRelationInfo(FriendRelation.self, null);
    final List rows = await _supabase.from('friendships').select('id, requester_id, addressee_id, status').or(
          'and(requester_id.eq.$me,addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.$me)',
        );
    if (rows.isEmpty) return const FriendRelationInfo(FriendRelation.none, null);
    final f = rows.first;
    if (f['status'] == 'accepted') return FriendRelationInfo(FriendRelation.friends, f['id']);
    if (f['requester_id'] == me) return FriendRelationInfo(FriendRelation.pendingOutgoing, f['id']);
    return FriendRelationInfo(FriendRelation.pendingIncoming, f['id']);
  }

  // --- 友達操作（サーバー関数経由で状態遷移を強制） ---

  Future<void> sendFriendRequest(String userId) =>
      _supabase.rpc('send_friend_request', params: {'p_addressee': userId});

  Future<void> respondFriendRequest(String friendshipId, bool accept) =>
      _supabase.rpc('respond_friend_request', params: {'p_id': friendshipId, 'p_accept': accept});

  Future<void> cancelFriendRequest(String friendshipId) =>
      _supabase.rpc('cancel_friend_request', params: {'p_id': friendshipId});

  Future<void> removeFriend(String userId) =>
      _supabase.rpc('remove_friend', params: {'p_other': userId});

  Future<List<Friend>> fetchFriends() async {
    final me = currentUserId;
    if (me == null) return [];
    final List rows = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, responded_at')
        .eq('status', 'accepted')
        .or('requester_id.eq.$me,addressee_id.eq.$me')
        .order('responded_at', ascending: false);

    final orderedOtherIds = <String>[];
    final meta = <String, Map<String, dynamic>>{};
    for (final f in rows) {
      final other = f['requester_id'] == me ? f['addressee_id'] : f['requester_id'];
      orderedOtherIds.add(other);
      meta[other] = {'fid': f['id'], 'since': f['responded_at']};
    }
    if (orderedOtherIds.isEmpty) return [];

    final List profiles = await _supabase
        .from('users')
        .select('id, username, avatar_url, bio')
        .inFilter('id', orderedOtherIds);
    final byId = {for (final p in profiles) p['id']: p};

    return orderedOtherIds.map<Friend>((id) {
      final p = byId[id];
      final since = meta[id]!['since'];
      return Friend(
        friendshipId: meta[id]!['fid'],
        since: since != null ? DateTime.parse(since).toLocal() : null,
        profile: UserProfile(
          id: id,
          username: p?['username'] ?? '',
          avatarUrl: p?['avatar_url'],
          bio: p?['bio'],
        ),
      );
    }).toList();
  }

  // --- いいね ---

  Future<bool> toggleLike(String postId) async {
    final res = await _supabase.rpc('toggle_like', params: {'p_post_id': postId});
    return res == true;
  }

  Future<Set<String>> fetchMyLikedPostIds() async {
    final me = currentUserId;
    if (me == null) return {};
    final List rows = await _supabase.from('likes').select('post_id').eq('user_id', me);
    return rows.map((r) => r['post_id'] as String).toSet();
  }

  Future<int> fetchLikeCount(String postId) async {
    final List rows = await _supabase.from('likes').select('id').eq('post_id', postId);
    return rows.length;
  }

  Future<List<UserProfile>> fetchLikers(String postId) async {
    final List rows = await _supabase
        .from('likes')
        .select('user_id, users(id, username, avatar_url, bio)')
        .eq('post_id', postId);
    return rows.map<UserProfile>((r) {
      final u = r['users'];
      return UserProfile(
        id: u?['id'] ?? r['user_id'],
        username: u?['username'] ?? '',
        avatarUrl: u?['avatar_url'],
        bio: u?['bio'],
      );
    }).toList();
  }

  // --- 通知 ---

  Future<List<AppNotification>> fetchNotifications() async {
    final me = currentUserId;
    if (me == null) return [];
    final List rows = await _supabase
        .from('notifications')
        .select(
          'id, type, actor_id, post_id, friendship_id, created_at, read_at, '
          'actor:users!notifications_actor_id_fkey(username, avatar_url)',
        )
        .eq('recipient_id', me)
        .order('created_at', ascending: false)
        .limit(100);

    return rows.map<AppNotification>((r) {
      final actor = r['actor'];
      return AppNotification(
        id: r['id'],
        type: r['type'] == 'friend_request' ? NotificationType.friendRequest : NotificationType.like,
        actorId: r['actor_id'],
        actorUsername: actor?['username'] ?? 'だれか',
        actorAvatarUrl: actor?['avatar_url'],
        postId: r['post_id'],
        friendshipId: r['friendship_id'],
        createdAt: DateTime.parse(r['created_at']).toLocal(),
        readAt: r['read_at'] != null ? DateTime.parse(r['read_at']).toLocal() : null,
      );
    }).toList();
  }

  Future<int> fetchUnreadCount() async {
    final me = currentUserId;
    if (me == null) return 0;
    final List rows = await _supabase
        .from('notifications')
        .select('id')
        .eq('recipient_id', me)
        .filter('read_at', 'is', null);
    return rows.length;
  }

  Future<void> markRead(String id) async {
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
