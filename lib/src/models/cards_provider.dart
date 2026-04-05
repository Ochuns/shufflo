import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_card_model.dart';
import 'supabase_repository.dart';

class CardsNotifier extends AsyncNotifier<List<ExperienceCardModel>> {
  @override
  Future<List<ExperienceCardModel>> build() async {
    final repo = ref.watch(supabaseRepositoryProvider);
    return await repo.fetchAllCards();
  }

  Future<void> submitPost({
    required String title,
    required ExperienceCategory category,
    required double rating,
    required String publicComment,
    required String privateComment,
    String? publicImagePath,
    String? privateImagePath,
    double? latitude,
    double? longitude,
  }) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.submitPost(
      title: title,
      category: category,
      rating: rating,
      publicComment: publicComment,
      privateComment: privateComment,
      publicImagePath: publicImagePath,
      privateImagePath: privateImagePath,
      latitude: latitude,
      longitude: longitude,
    );
    ref.invalidateSelf();
    await future;
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<ExperienceCardModel>>(() {
  return CardsNotifier();
});
