import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'experience_card_model.dart';
import 'social_models.dart';
import 'social_repository.dart';
import 'supabase_repository.dart';

/// 任意ユーザーのプロフィール。
final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) {
  return ref.watch(socialRepositoryProvider).fetchUserProfile(userId);
});

/// 自分のプロフィール。
final myProfileProvider = FutureProvider<UserProfile?>((ref) {
  final repo = ref.watch(socialRepositoryProvider);
  final me = repo.currentUserId;
  if (me == null) return Future.value(null);
  return repo.fetchUserProfile(me);
});

/// 指定ユーザーのタイムライン（Public+Private統合）。
final timelineProvider =
    FutureProvider.family<List<ExperienceCardModel>, String>((ref, userId) {
  return ref.watch(supabaseRepositoryProvider).fetchTimelineCards(userId);
});

/// 相手との関係（申請ボタンの出し分け用）。
final relationProvider =
    FutureProvider.family<FriendRelationInfo, String>((ref, userId) {
  return ref.watch(socialRepositoryProvider).fetchRelation(userId);
});

/// ユーザー検索（query ごと）。
final userSearchProvider =
    FutureProvider.family<List<UserSearchResult>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value(const []);
  return ref.watch(socialRepositoryProvider).searchUsers(query);
});

/// 友達一覧。
final friendsProvider = FutureProvider<List<Friend>>((ref) {
  return ref.watch(socialRepositoryProvider).fetchFriends();
});

/// 通知一覧。
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(socialRepositoryProvider).fetchNotifications();
});

/// 未読通知件数。
final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(socialRepositoryProvider).fetchUnreadCount();
});

/// 自分がいいね済みの post_id 集合（楽観更新）。
class MyLikesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return ref.watch(socialRepositoryProvider).fetchMyLikedPostIds();
  }

  /// いいね切替。戻り値は成功可否。
  Future<bool> toggle(String postId) async {
    if (!state.hasValue) return false;
    final previous = state;
    final current = state.value!;
    final liked = current.contains(postId);
    // 楽観更新
    state = AsyncData(liked ? ({...current}..remove(postId)) : {...current, postId});
    try {
      final serverLiked = await ref.read(socialRepositoryProvider).toggleLike(postId);
      final s = state.value ?? {};
      state = AsyncData(serverLiked ? {...s, postId} : ({...s}..remove(postId)));
      return true;
    } catch (_) {
      state = previous; // ロールバック
      return false;
    }
  }
}

final myLikedPostIdsProvider =
    AsyncNotifierProvider<MyLikesNotifier, Set<String>>(MyLikesNotifier.new);

/// 指定 post のいいね数（自分のカード詳細で表示）。
final likeCountProvider = FutureProvider.family<int, String>((ref, postId) {
  // 自分のいいね状態が変わったら数も取り直す
  ref.watch(myLikedPostIdsProvider);
  return ref.watch(socialRepositoryProvider).fetchLikeCount(postId);
});

/// 指定 post のいいねしたユーザー一覧（自分のカード詳細で表示）。
final likersProvider = FutureProvider.family<List<UserProfile>, String>((ref, postId) {
  ref.watch(myLikedPostIdsProvider);
  return ref.watch(socialRepositoryProvider).fetchLikers(postId);
});
