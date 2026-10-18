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
        return '飲食店';
      case ExperienceCategory.cafe:
        return 'カフェ';
      case ExperienceCategory.sightseeing:
        return '観光';
      case ExperienceCategory.amusement:
        return '遊び';
      case ExperienceCategory.other:
        return 'その他';
    }
  }

  /// 「会津の食」テーマで、カード作成時にユーザーへ提示するカテゴリ（飲食中心）。
  /// enum 自体は残し（既存データ・将来拡張のため）、選択肢だけを絞る。
  static const List<ExperienceCategory> foodCategories = [
    ExperienceCategory.restaurant,
    ExperienceCategory.cafe,
  ];

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

  IconData get icon {
    switch (this) {
      case ExperienceCategory.restaurant:
        return Icons.restaurant_menu;
      case ExperienceCategory.cafe:
        return Icons.local_cafe;
      case ExperienceCategory.sightseeing:
        return Icons.landscape;
      case ExperienceCategory.amusement:
        return Icons.attractions;
      case ExperienceCategory.other:
        return Icons.star;
    }
  }
}

class ExperienceCardModel {
  final String id;
  final String? postId; // もととなるポストID (削除・編集用)
  final String? authorId; // 投稿者ID (権限チェック用)
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
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;

  const ExperienceCardModel({
    required this.id,
    this.postId,
    this.authorId,
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
    this.createdAt,
    this.latitude,
    this.longitude,
  });
}
