import 'package:flutter/material.dart';

enum ExperienceCategory {
  restaurant,
  cafe,
  sightseeing,
  amusement,
  other,
}

enum CardRarity {
  common,
  rare,
  epic,
  legendary,
}

extension ExperienceCategoryExtension on ExperienceCategory {
  String get label {
    switch (this) {
      case ExperienceCategory.restaurant:
        return 'Restaurant';
      case ExperienceCategory.cafe:
        return 'Cafe';
      case ExperienceCategory.sightseeing:
        return 'Sightseeing';
      case ExperienceCategory.amusement:
        return 'Amusement';
      case ExperienceCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case ExperienceCategory.restaurant:
        return const Color(0xFFFF6B6B); // Soft Coral
      case ExperienceCategory.cafe:
        return const Color(0xFFF59E0B); // Amber
      case ExperienceCategory.sightseeing:
        return const Color(0xFF10B981); // Emerald
      case ExperienceCategory.amusement:
        return const Color(0xFF8B5CF6); // Violet
      case ExperienceCategory.other:
        return const Color(0xFF64748B); // Slate
    }
  }
}

class ExperienceCardModel {
  final String id;
  final String title;
  final String imageUrl;
  final double rating;
  final ExperienceCategory category;
  final String comment;
  final String authorName;
  final String authorAvatarUrl;
  final String duration;
  final String priceRange;
  final List<String> tags; // e.g. ["初デート向き", "夜景"]
  final bool isPublic;
  final String? localImagePath;
  final CardRarity rarity;

  const ExperienceCardModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.category,
    required this.comment,
    required this.authorName,
    required this.authorAvatarUrl,
    this.duration = '1-2h',
    this.priceRange = '\$\$',
    this.tags = const [],
    this.isPublic = true,
    this.localImagePath,
    this.rarity = CardRarity.common,
  });
}
