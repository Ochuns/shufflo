import 'experience_card_model.dart';
import 'deck_model.dart';

final List<ExperienceCardModel> initialMockCards = [
  ExperienceCardModel(
    id: '1',
    title: 'Blue Bottle Coffee',
    imageUrl: 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=600&q=80&fit=crop',
    rating: 4.5,
    category: ExperienceCategory.cafe,
    comment: 'Great atmosphere, perfect for a short break.',
    authorName: 'Creative Editor',
    authorAvatarUrl: 'https://i.pravatar.cc/300',
    duration: '1h',
    priceRange: '\$\$',
    tags: ['Relaxing', 'Good Coffee'],
    isPublic: true,
    rarity: CardRarity.common,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  ExperienceCardModel(
    id: '2',
    title: 'Kyoto Imperial Palace',
    imageUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600&q=80&fit=crop',
    rating: 4.8,
    category: ExperienceCategory.sightseeing,
    comment: 'Beautiful gardens and historic buildings.',
    authorName: 'Creative Editor',
    authorAvatarUrl: 'https://i.pravatar.cc/300',
    duration: '2-3h',
    priceRange: 'Free',
    tags: ['Historic', 'Photo Spot'],
    isPublic: true,
    rarity: CardRarity.legendary,
    createdAt: DateTime.now(),
  ),
  ExperienceCardModel(
    id: '3',
    title: 'Sushi Zanmai',
    imageUrl: 'https://images.unsplash.com/photo-1553621042-f6e147245754?w=600&q=80&fit=crop',
    rating: 4.2,
    category: ExperienceCategory.restaurant,
    comment: 'Fresh sushi at a reasonable price.',
    authorName: 'Creative Editor',
    authorAvatarUrl: 'https://i.pravatar.cc/300',
    duration: '1.5h',
    priceRange: '\$\$\$',
    tags: ['Dinner', 'Seafood'],
    isPublic: false, // Private Card example
    rarity: CardRarity.rare,
    createdAt: DateTime.now(),
  ),
];

final DeckModel mockDemoDeck = DeckModel(
  id: 'd1',
  title: 'Kyoto Trip',
  date: DateTime.now(),
  cards: initialMockCards,
  location: 'Kyoto, Japan',
);

final List<DeckModel> initialMockDecks = [mockDemoDeck];
