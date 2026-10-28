import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/experience_card_model.dart';
import '../../models/social_providers.dart';
import '../../models/supabase_repository.dart';
import '../../common_widgets/rating_stars.dart';
import '../../common_widgets/category_tag.dart';
import '../../utils/relative_time.dart';
import 'like_action.dart';

/// 指定ユーザーの Public/Private 統合タイムライン（新しい順）。
class TimelineList extends ConsumerWidget {
  const TimelineList({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timelineProvider(userId));
    final myId = ref.watch(supabaseRepositoryProvider).currentUserId;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('読み込みに失敗しました')),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
            child: Text('まだ投稿がありません', style: TextStyle(color: Colors.grey)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(timelineProvider(userId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TimelineTile(
              card: cards[i],
              isOwner: cards[i].authorId == myId,
            ),
          ),
        );
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.card, required this.isOwner});
  final ExperienceCardModel card;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/card_detail', extra: card),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AizuColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AizuColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CardImage(card: card),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _AuthorAvatar(url: card.authorAvatarUrl),
                    ),
                    if (card.createdAt != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _PostedAtBadge(createdAt: card.createdAt!),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AizuColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CategoryTag(category: card.category),
                    ],
                  ),
                  // 評価の行の右端（カテゴリタグの下）にいいね
                  // 自分のカードはいいね数、友達のカードはトグル
                  Row(
                    children: [
                      RatingStars(rating: card.rating),
                      const Spacer(),
                      // ボタンの余白を詰めて、行の高さが広がらないようにする
                      Theme(
                        data: Theme.of(context).copyWith(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: LikeAction(
                          postId: card.postId,
                          authorId: card.authorId ?? '',
                          isOwner: isOwner,
                          inactiveColor: AizuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (card.comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AizuColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.card});
  final ExperienceCardModel card;

  @override
  Widget build(BuildContext context) {
    final local = card.localImagePath;
    if (local != null && File(local).existsSync()) {
      return Image.file(File(local), fit: BoxFit.cover);
    }
    if (card.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: card.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: AizuColors.surfaceAlt),
        errorWidget: (_, _, _) => Container(
          color: AizuColors.surfaceAlt,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
    return Container(color: AizuColors.surfaceAlt);
  }
}

/// 写真右下に重ねる「〇時間前」表示。
class _PostedAtBadge extends StatelessWidget {
  const _PostedAtBadge({required this.createdAt});
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        relativeTime(createdAt),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 写真右上に重ねる投稿者アイコン。
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AizuColors.surfaceAlt,
        backgroundImage: url.isNotEmpty
            ? CachedNetworkImageProvider(url)
            : null,
        child: url.isEmpty
            ? const Icon(
                Icons.person,
                size: 18,
                color: AizuColors.textSecondary,
              )
            : null,
      ),
    );
  }
}
