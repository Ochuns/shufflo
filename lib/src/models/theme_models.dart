// テーマ別コレクションのモデル。

class ThemeSummary {
  final String id;
  final String name;
  final int sortOrder;
  final String? rewardTitle;
  final String? rewardDescription;
  final int targetCount; // 対象店舗数
  final int collectedCount; // 現サイクルで集めた数
  final int cycleNumber;

  const ThemeSummary({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.rewardTitle,
    this.rewardDescription,
    required this.targetCount,
    required this.collectedCount,
    required this.cycleNumber,
  });

  bool get isComplete => targetCount > 0 && collectedCount >= targetCount;
  double get progress => targetCount == 0 ? 0 : (collectedCount / targetCount).clamp(0, 1);
}

/// テーマ詳細の店舗スロット（店舗ごとに1つ）。
class ThemeStoreSlot {
  final String storeId;
  final String storeName;
  final bool visited;
  final String? cardImageUrl;
  final String? cardLocalPath;
  final String? postId;

  const ThemeStoreSlot({
    required this.storeId,
    required this.storeName,
    required this.visited,
    this.cardImageUrl,
    this.cardLocalPath,
    this.postId,
  });
}

class ThemeDetail {
  final ThemeSummary summary;
  final List<ThemeStoreSlot> slots;
  const ThemeDetail({required this.summary, required this.slots});
}
