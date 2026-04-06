import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/experience_card_model.dart';
import '../../common_widgets/rating_stars.dart';

class CardDetailScreen extends StatelessWidget {
  final ExperienceCardModel model;

  const CardDetailScreen({super.key, required this.model});

  Color _getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return const Color(0xFF9E9E9E); // Grey
      case CardRarity.rare:
        return const Color(0xFF00E5FF); // Cyan
      case CardRarity.epic:
        return const Color(0xFFD500F9); // Purple
      case CardRarity.legendary:
        return const Color(0xFFFFD700); // Gold
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

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // ダークな宇宙的背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 6 / 9.5, // TCGカードに近い縦横比
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // レアリティに応じた外枠
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.5),
                    blurRadius: isPremium ? 20 : 8,
                    spreadRadius: isPremium ? 4 : 0,
                  ),
                ],
                gradient: isPremium
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          rarityColor.withOpacity(0.8),
                          Color(0xFF2C2C2C),
                          rarityColor,
                        ],
                      )
                    : null, // フォールバックは下のcolorを使用
                color: const Color(0xFF2C2C2C),
                border: Border.all(
                  color: rarityColor,
                  width: isPremium ? 3 : 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFF1E1E1E), // カード内部の背景色
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- 1. Header (Attribute & Title) ---
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 属性マーク (Category Icon in a Badge)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: model.category.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
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
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                model.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // --- 2. Rarity Indicator & Level ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getRarityLabel(model.rarity).toUpperCase(),
                              style: TextStyle(
                                color: rarityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            // レベル（星の数）
                            RatingStars(rating: model.rating, size: 14, color: Colors.amberAccent),
                          ],
                        ),
                      ),

                      // --- 3. Hero Image Slot (Art) ---
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isPremium ? rarityColor.withOpacity(0.8) : Colors.grey.shade700,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Hero(
                              tag: 'card_image_\${model.id}',
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

                      // --- 4. Tag / Keyword bar ---
                      if (model.tags.isNotEmpty)
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
                      
                      // --- 5. Skill / Flavor Text Box ---
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

                      // --- 6. Footer (Author & Info) ---
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
