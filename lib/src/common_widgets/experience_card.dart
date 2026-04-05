import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/experience_card_model.dart';
import 'category_tag.dart';
import 'rating_stars.dart';

class ExperienceCard extends StatelessWidget {
  final ExperienceCardModel model;
  final VoidCallback? onTap;
  final bool isCompact;

  const ExperienceCard({
    super.key,
    required this.model,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: isCompact ? 4 : 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (model.localImagePath != null)
                        Image.file(
                          File(model.localImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Icon(Icons.error)),
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: model.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade300, child: const Icon(Icons.error)),
                        ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: CategoryTag(
                          category: model.category,
                          fontSize: isCompact ? 10 : 12,
                          padding: isCompact ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: isCompact ? 3 : 4,
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 10.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 14 : 18,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 6),
                          Text(
                            model.comment,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RatingStars(rating: model.rating, size: isCompact ? 12 : 16),
                            if (!isCompact)
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: CachedNetworkImageProvider(model.authorAvatarUrl),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    model.authorName,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
