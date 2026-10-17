// 友達・いいね・通知まわりのモデル。

class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final int postCount;

  const UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.postCount = 0,
  });

  String get displayAvatar =>
      (avatarUrl != null && avatarUrl!.isNotEmpty) ? avatarUrl! : 'https://i.pravatar.cc/300';
}

/// 自分から見た相手との関係。
enum FriendRelation {
  self,
  none,
  pendingOutgoing, // 自分が送った申請（申請中）
  pendingIncoming, // 相手から受けた申請
  friends,
}

class FriendRelationInfo {
  final FriendRelation relation;
  final String? friendshipId;
  const FriendRelationInfo(this.relation, this.friendshipId);
}

class UserSearchResult {
  final UserProfile profile;
  final FriendRelation relation;
  final String? friendshipId;
  const UserSearchResult({
    required this.profile,
    required this.relation,
    this.friendshipId,
  });
}

class Friend {
  final String friendshipId;
  final UserProfile profile;
  final DateTime? since;
  const Friend({required this.friendshipId, required this.profile, this.since});
}

enum NotificationType { like, friendRequest }

class AppNotification {
  final String id;
  final NotificationType type;
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;
  final String? postId;
  final String? friendshipId;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.postId,
    this.friendshipId,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;
}
