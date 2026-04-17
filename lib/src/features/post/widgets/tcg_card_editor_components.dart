import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/experience_card_model.dart';
import 'package:lucide_icons/lucide_icons.dart';

Color _getRarityColor(CardRarity rarity) {
  switch (rarity) {
    case CardRarity.common: return const Color(0xFF9E9E9E);
    case CardRarity.rare: return const Color(0xFF00E5FF);
    case CardRarity.epic: return const Color(0xFFD500F9);
    case CardRarity.legendary: return const Color(0xFFFFD700);
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

class TcgCardEditorFront extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController commentController;
  final ExperienceCategory selectedCategory;
  final double rating;
  final String? imagePath;
  final VoidCallback onPickImage;

  const TcgCardEditorFront({
    super.key,
    required this.titleController,
    required this.commentController,
    required this.selectedCategory,
    required this.rating,
    required this.imagePath,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(CardRarity.common); // 作成されるカード(Common)と完全に統一

    return AspectRatio(
      aspectRatio: 6 / 9.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
          color: const Color(0xFF2C2C2C),
          border: Border.all(
            color: rarityColor,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Attribute & Title)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedCategory.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: selectedCategory.color.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(selectedCategory),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14, // 文字を小さく
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                          maxLength: 20,
                          decoration: InputDecoration(
                            hintText: 'Enter title',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), // もう少し丸みを持たせる
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.white, width: 1.5),
                            ),
                            fillColor: Colors.black26,
                            filled: true,
                            isDense: true,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 2. Rarity Indicator & Level
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getRarityLabel(CardRarity.common).toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'RECOMMENDATION',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: List.generate(5, (index) {
                              final starValue = index + 1;
                              return Icon(
                                starValue <= rating ? Icons.star : Icons.star_border,
                                color: Colors.amberAccent,
                                size: 14,
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Hero Image Slot (Art)
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: onPickImage,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.black26,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: imagePath != null
                            ? Image.file(
                                File(imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_a_photo, color: Colors.white54, size: 40),
                                    const SizedBox(height: 8),
                                    const Text('Tap to Add Public Photo', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // 5. Flavor Text Box (Edit mode)
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
                    child: TextField(
                      controller: commentController,
                      style: const TextStyle(
                         color: Colors.white70,
                         height: 1.5,
                         fontSize: 13,
                      ),
                      maxLength: 100, // 長文制限
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Add a memorable flavor text for this card...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        isDense: true,
                        counterStyle: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TcgCardEditorBack extends StatelessWidget {
  final TextEditingController titleController; // タイトルも同様に表示させる
  final TextEditingController commentController;
  final ExperienceCategory selectedCategory;
  final double rating;
  final String? imagePath;
  final VoidCallback onPickImage;

  const TcgCardEditorBack({
    super.key,
    required this.titleController,
    required this.commentController,
    required this.selectedCategory,
    required this.rating,
    required this.imagePath,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    // 表面と完全に統一されたデザインを使用
    final rarityColor = _getRarityColor(CardRarity.common); // 作成されるカード(Common)と完全に統一

    return AspectRatio(
      aspectRatio: 6 / 9.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
          color: const Color(0xFF2C2C2C),
          border: Border.all(
            color: rarityColor,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Attribute & Title)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedCategory.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: selectedCategory.color.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(selectedCategory),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          maxLength: 20,
                          decoration: InputDecoration(
                            hintText: 'Enter title',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.white, width: 1.5),
                            ),
                            counterText: '',
                            fillColor: Colors.black26,
                            filled: true,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14, 
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      // Private インジケーター
                      const Icon(LucideIcons.lock, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
                
                // 2. Rarity Indicator & Level
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getRarityLabel(CardRarity.common).toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'RECOMMENDATION',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: List.generate(5, (index) {
                              final starValue = index + 1;
                              return Icon(
                                starValue <= rating ? Icons.star : Icons.star_border,
                                color: Colors.amberAccent,
                                size: 14,
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Hero Image Slot (Art) -> Private Photo
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: onPickImage,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.black26,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: imagePath != null
                            ? Image.file(
                                File(imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_a_photo, color: Colors.white54, size: 40),
                                    const SizedBox(height: 8),
                                    const Text('Tap to Add Private Photo', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // 5. Flavor Text Box (Edit mode) -> Private Note
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
                    child: TextField(
                      controller: commentController,
                      style: const TextStyle(
                         color: Colors.white70,
                         height: 1.5,
                         fontSize: 13,
                      ),
                      maxLength: 150, // 長文制限
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Keep your secret memories here...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        isDense: true,
                        counterStyle: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
