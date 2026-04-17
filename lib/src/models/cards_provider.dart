import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_card_model.dart';
import 'supabase_repository.dart';
import 'decks_provider.dart';

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
    String? deckId,
  }) async {
    try {
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
        deckId: deckId,
      );

      ref.invalidateSelf();
      ref.invalidate(decksProvider); // デッキ一覧を最新に更新
      await future;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCard(String postId) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.deletePost(postId);
    ref.invalidateSelf();
    ref.invalidate(decksProvider); // デッキからも削除されたことをUIに即座に反映
    await future;
  }

  Future<void> updateCard({
    required String postId,
    required String title,
    required ExperienceCategory category,
    required double rating,
    required String publicComment,
    required String privateComment,
  }) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.updatePost(
      postId: postId,
      title: title,
      category: category,
      rating: rating,
      publicComment: publicComment,
      privateComment: privateComment,
    );
    ref.invalidateSelf();
    await future;
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<ExperienceCardModel>>(() {
  return CardsNotifier();
});
