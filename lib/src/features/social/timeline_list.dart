import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/experience_card_model.dart';
import '../../models/social_providers.dart';
import '../../common_widgets/rating_stars.dart';
import '../../common_widgets/category_tag.dart';

/// 指定ユーザーの Public/Private 統合タイムライン（新しい順）。
class TimelineList extends ConsumerWidget {
  const TimelineList({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timelineProvider(userId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('読み込みに失敗しました')),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
            child: Text('まだ投稿がねぇな', style: TextStyle(color: Colors.grey)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(timelineProvider(userId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TimelineTile(card: cards[i]),
          ),
        );
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.card});
  final ExperienceCardModel card;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/card_detail', extra: card),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CardImage(card: card),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _VisibilityBadge(isPublic: card.isPublic),
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
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CategoryTag(category: card.category),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RatingStars(rating: card.rating),
                  if (card.comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
        placeholder: (_, _) => Container(color: const Color(0xFF1E1E1E)),
        errorWidget: (_, _, _) =>
            Container(color: const Color(0xFF1E1E1E), child: const Icon(Icons.image_not_supported, color: Colors.grey)),
      );
    }
    return Container(color: const Color(0xFF1E1E1E));
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isPublic});
  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPublic ? Icons.public : Icons.lock_outline, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
