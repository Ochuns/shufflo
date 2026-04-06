import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/experience_card_model.dart';
import 'rating_stars.dart';

class TcgCardView extends StatelessWidget {
  final ExperienceCardModel model;
  final bool isCompact;

  const TcgCardView({
    super.key,
    required this.model,
    this.isCompact = false,
  });

  Color _getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return const Color(0xFF9E9E9E);
      case CardRarity.rare:
        return const Color(0xFF00E5FF);
      case CardRarity.epic:
        return const Color(0xFFD500F9);
      case CardRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  String _getRarityLabel(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common: return 'Common';
      case CardRarity.rare: return 'Rare';
      case CardRarity.epic: return 'Epic';
      case CardRarity.legendary: return 'Legendary';
    }
  }

  IconData _getCategoryIcon(ExperienceCategory category) {
    switch (category) {
      case ExperienceCategory.restaurant: return Icons.restaurant_menu;
      case ExperienceCategory.cafe: return Icons.local_cafe;
      case ExperienceCategory.sightseeing: return Icons.landscape;
      case ExperienceCategory.amusement: return Icons.attractions;
      case ExperienceCategory.other: return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(model.rarity);
    final isPremium = model.rarity == CardRarity.epic || model.rarity == CardRarity.legendary;

    return AspectRatio(
      aspectRatio: 6 / 9.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isCompact ? 12 : 20),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withOpacity(0.5),
              blurRadius: isPremium ? (isCompact ? 12 : 20) : 8,
              spreadRadius: isPremium ? (isCompact ? 2 : 4) : 0,
            ),
          ],
          gradient: isPremium
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    rarityColor.withOpacity(0.8),
                    const Color(0xFF2C2C2C),
                    rarityColor,
                  ],
                )
              : null,
          color: const Color(0xFF2C2C2C),
          border: Border.all(
            color: rarityColor,
            width: isPremium ? (isCompact ? 2 : 3) : (isCompact ? 1 : 2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCompact ? 10 : 16),
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Attribute & Title)
                Padding(
                  padding: EdgeInsets.all(isCompact ? 8.0 : 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isCompact ? 20 : 28,
                        height: isCompact ? 20 : 28,
                        decoration: BoxDecoration(
                          color: model.category.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: isCompact ? 1 : 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: model.category.color.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(model.category),
                          size: isCompact ? 12 : 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: isCompact ? 6 : 10),
                      Expanded(
                        child: Text(
                          model.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: isCompact ? 0.5 : 1.1,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 2. Rarity Indicator & Level
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 12.0).copyWith(bottom: isCompact ? 4 : 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getRarityLabel(model.rarity).toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: isCompact ? 8 : 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isCompact ? 1.0 : 2.0,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isCompact)
                            const Text(
                              'RECOMMENDATION',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          if (!isCompact) const SizedBox(height: 2),
                          RatingStars(
                            rating: model.rating, 
                            size: isCompact ? 10 : 14, 
                            color: Colors.amberAccent
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Hero Image Slot (Art)
                Expanded(
                  flex: isCompact ? 10 : 5, // コンパクト時は画像を大きく
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isPremium ? rarityColor.withOpacity(0.8) : Colors.grey.shade700,
                        width: isCompact ? 1 : 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Hero(
                        tag: 'card_image_${model.id}',
                        child: model.localImagePath != null
                            ? Image.file(File(model.localImagePath!), fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: model.imageUrl,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),

                // 4. Tag / Keyword bar (Compact時は1つだけ、または非表示)
                if (model.tags.isNotEmpty && !isCompact)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, left: 12, right: 12),
                    child: Wrap(
                      spacing: 6,
                      children: model.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '[$tag]',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      )).toList(),
                    ),
                  ),
                
                // 5. Skill / Flavor Text Box (Compact時は非表示)
                if (!isCompact)
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(12.0),
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Text(
                          model.comment,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. Footer (Author & Info) (Compact時は非表示)
                if (!isCompact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: CachedNetworkImageProvider(model.authorAvatarUrl),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Illus. \${model.authorName}',
                          style: const TextStyle(color: Colors.white54, fontSize: 9, fontStyle: FontStyle.italic),
                        ),
                        const Spacer(),
                        Text(
                          "ID: \${model.id.padLeft(4, '0')}  ©Shufflo",
                          style: const TextStyle(color: Colors.white38, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                
                // コンパクト時の余白調整
                if (isCompact) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
