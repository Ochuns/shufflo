import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'deck_model.dart';
import 'supabase_repository.dart';

class DecksNotifier extends AsyncNotifier<List<DeckModel>> {
  @override
  Future<List<DeckModel>> build() async {
    final repo = ref.watch(supabaseRepositoryProvider);
    return await repo.fetchAllDecks();
  }

  Future<void> createDeck(String title) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.createDeck(title: title);
    // 状態を無効化して再取得
    ref.invalidateSelf();
    // 完了まで待機
    await future;
  }

  Future<void> deleteDeck(String deckId) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.deleteDeck(deckId);
    ref.invalidateSelf();
    await future;
  }
}

final decksProvider = AsyncNotifierProvider<DecksNotifier, List<DeckModel>>(() {
  return DecksNotifier();
});
