import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_models.dart';
import 'theme_repository.dart';

/// アクティブなテーマ一覧（進捗順）。
final themesProvider = FutureProvider<List<ThemeSummary>>((ref) {
  return ref.watch(themeRepositoryProvider).fetchThemes();
});

/// テーマ詳細。
final themeDetailProvider =
    FutureProvider.family<ThemeDetail, String>((ref, themeId) {
  return ref.watch(themeRepositoryProvider).fetchThemeDetail(themeId);
});
