import 'experience_card_model.dart';

class DeckModel {
  final String id;
  final String title;
  final DateTime date;
  final List<ExperienceCardModel> cards;
  final String location;

  const DeckModel({
    required this.id,
    required this.title,
    required this.date,
    required this.cards,
    required this.location,
  });
}
