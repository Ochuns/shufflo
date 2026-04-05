import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_card_model.dart';
import 'mock_data.dart';

class CardsNotifier extends Notifier<List<ExperienceCardModel>> {
  @override
  List<ExperienceCardModel> build() {
    return initialMockCards;
  }

  void addCard(ExperienceCardModel card) {
    state = [...state, card];
  }
}

final cardsProvider = NotifierProvider<CardsNotifier, List<ExperienceCardModel>>(() {
  return CardsNotifier();
});
