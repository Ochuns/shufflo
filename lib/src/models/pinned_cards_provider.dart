import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_repository.dart';

class PinnedCardsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final repo = ref.watch(supabaseRepositoryProvider);
    return await repo.fetchPinnedCardIds();
  }

  Future<bool> togglePin(String cardId) async {
    final previousState = state;
    if (!state.hasValue) return false;
    
    final currentSet = state.value!;
    final isCurrentlyPinned = currentSet.contains(cardId);
    
    // オプティミスティックUI更新（通信を待たずにUIを即座に切り替える）
    if (isCurrentlyPinned) {
      state = AsyncData({...currentSet}..remove(cardId));
    } else {
      state = AsyncData({...currentSet, cardId});
    }

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      await repo.togglePinCard(cardId, !isCurrentlyPinned);
      return true;
    } catch (e) {
      // 失敗した場合は元に戻す
      state = previousState;
      return false;
    }
  }
}

final pinnedCardsProvider = AsyncNotifierProvider<PinnedCardsNotifier, Set<String>>(() {
  return PinnedCardsNotifier();
});
