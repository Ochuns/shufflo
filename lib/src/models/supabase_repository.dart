import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_card_model.dart';
import 'deck_model.dart';
import 'mock_data.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

final supabaseRepositoryProvider = Provider((ref) => SupabaseRepository());

class SupabaseRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // 1. ユーザー存在チェック・作成
  Future<void> _ensureUserExists() async {
    final userId = currentUserId;
    if (userId == null) throw Exception("User not signed in");

    final res = await _supabase.from('users').select('id').eq('id', userId).maybeSingle();
    if (res == null) {
      await _supabase.from('users').insert({
        'id': userId,
        'username': 'Anonymous Explorer',
        'avatar_url': 'https://i.pravatar.cc/300',
      });
    }
  }

  // 2. Storageへアップロード
  Future<String?> uploadImage(String? localPath, String bucket) async {
    if (localPath == null || localPath.isEmpty) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}_local.jpg";
    final ext = p.extension(localPath);
    final fullPath = "${DateTime.now().millisecondsSinceEpoch}$ext";
    
    try {
      await _supabase.storage.from(bucket).upload(fullPath, file);
      return _supabase.storage.from(bucket).getPublicUrl(fullPath);
    } catch (e) {
      // バケットがない、認証エラーなどのMVP挙動でフォールバック
      return null;
    }
  }

  // 3. すべての関連テーブルに新しいカード(Post)を追加し、投稿IDを返す
  Future<String> submitPost({
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
    await _ensureUserExists();

    final userId = currentUserId!;
    
    // 画像アップロード
    final pubImageUrl = await uploadImage(publicImagePath, 'card-images') ?? 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=600&q=80';
    final privImageUrl = await uploadImage(privateImagePath, 'card-images') ?? 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600&q=80';

    // MVP fallback (渋谷駅周辺) if no location
    final lat = latitude ?? 35.6580;
    final lon = longitude ?? 139.7016;
    final locName = latitude != null ? 'Extracted Location' : 'Unknown Location (Default)';

    try {
      final locationInsert = await _supabase.from('locations').insert({
        'name': locName,
        'latitude': lat,
        'longitude': lon,
        'address': 'No Address',
      }).select('id').single();
      final locationId = locationInsert['id'];

      // Post
      final postInsert = await _supabase.from('posts').insert({
        'user_id': userId,
        'location_id': locationId,
        'title': title,
        'category': category.name,
        'rating': rating.toInt(),
        'comment': publicComment,
        'public_image_url': pubImageUrl,
        'private_image_url': privImageUrl,
      }).select('id').single();
      final postId = postInsert['id'];

      // Public Card (with PostGIS Point)
      await _supabase.from('public_cards').insert({
        'post_id': postId,
        'user_id': userId,
        'location_id': locationId,
        'title': title,
        'category': category.name,
        'rating': rating.toInt(),
        'comment': publicComment,
        'image_url': pubImageUrl,
        'location_coords': 'POINT($lon $lat)'
      });

      // Private Card
      await _supabase.from('private_cards').insert({
        'post_id': postId,
        'user_id': userId,
        'location_id': locationId,
        'comment': privateComment,
        'image_url': privImageUrl,
        'visited_date': DateTime.now().toIso8601String(),
      });

      return postId;
    } catch (e) {
      debugPrint("submitPost Supabase error: $e. Returning mock ID for local testing.");
      return 'mock_post_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // 4. Public/Privateカードの一括取得
  Future<List<ExperienceCardModel>> fetchAllCards() async {
    final List<ExperienceCardModel> cards = [];
    final userId = currentUserId;

    // Public Cards
    final pubRes = await _supabase.from('public_cards')
        .select('*, users(username, avatar_url)')
        .filter('deleted_at', 'is', null); // 論理削除されていないもののみ
    for (var row in pubRes) {
      cards.add(ExperienceCardModel(
        id: row['id'],
        postId: row['post_id'],
        authorId: row['user_id'],
        title: row['title'] ?? 'Untitled',
        imageUrl: row['image_url'] ?? '',
        rating: (row['rating'] ?? 3).toDouble(),
        category: ExperienceCategory.values.firstWhere((e) => e.name == row['category'], orElse: () => ExperienceCategory.other),
        comment: row['comment'] ?? '',
        authorName: row['users'] != null ? row['users']['username'] : 'Explorer',
        authorAvatarUrl: row['users'] != null ? row['users']['avatar_url'] : 'https://i.pravatar.cc/300',
        isPublic: true,
        rarity: CardRarity.values.firstWhere((e) => e.name == (row['rarity'] ?? 'common'), orElse: () => CardRarity.common),
        createdAt: row['created_at'] != null ? DateTime.parse(row['created_at']).toLocal() : null,
      ));
    }

    if (userId != null) {
      // Private Cards for the specific user
      final privRes = await _supabase.from('private_cards')
          .select('*, posts!inner(title, category, rating), users(username, avatar_url)')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null); // 論理削除されていないもののみ
      for (var row in privRes) {
        final postData = row['posts'];
        cards.add(ExperienceCardModel(
          id: row['id'],
          postId: row['post_id'],
          authorId: row['user_id'],
          title: postData?['title'] ?? 'Untitled',
          imageUrl: row['image_url'] ?? '',
          rating: (postData?['rating'] ?? 3).toDouble(),
          category: ExperienceCategory.values.firstWhere((e) => e.name == postData?['category'], orElse: () => ExperienceCategory.other),
          comment: row['comment'] ?? '',
          authorName: row['users'] != null ? row['users']['username'] : 'Explorer',
          authorAvatarUrl: row['users'] != null ? row['users']['avatar_url'] : 'https://i.pravatar.cc/300',
          isPublic: false,
          rarity: CardRarity.values.firstWhere((e) => e.name == (postData?['rarity'] ?? 'common'), orElse: () => CardRarity.common),
          createdAt: row['visited_date'] != null ? DateTime.parse(row['visited_date']).toLocal() : null,
        ));
      }
    }

    // デモ/開発用にデータが空の場合はモックを返す (Supabase未設定時などの対策)
    if (cards.isEmpty) {
      return initialMockCards;
    }

    return cards;
  }

  // 5. カード（Post）の論理削除 (DBトリガーにより他テーブルも自動連動)
  Future<void> deletePost(String postId) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _supabase.from('posts').update({'deleted_at': now}).eq('id', postId);
    } catch (e) {
      // ローカルモック用フォールバック
      debugPrint("deletePost failed (Offline mode?): $e");
    }

    // デッキからの自動除外 (ローカルのフォールバック)
    for (int i = 0; i < _localDecks.length; i++) {
      final deck = _localDecks[i];
      final originalLength = deck.cards.length;
      final filteredCards = deck.cards.where((c) => c.postId != postId && c.id != postId).toList();
      
      if (filteredCards.length != originalLength) {
        _localDecks[i] = DeckModel(
          id: deck.id,
          title: deck.title,
          date: deck.date,
          cards: filteredCards,
          location: deck.location,
        );
      }
    }
  }

  // 6. カード（Post）の更新
  Future<void> updatePost({
    required String postId,
    required String title,
    required ExperienceCategory category,
    required double rating,
    required String publicComment,
    required String privateComment,
  }) async {
    await _supabase.from('posts').update({
      'title': title,
      'category': category.name,
      'rating': rating.toInt(),
      'comment': publicComment,
    }).eq('id', postId);

    await _supabase.from('public_cards').update({
      'title': title,
      'category': category.name,
      'rating': rating.toInt(),
      'comment': publicComment,
    }).eq('post_id', postId);

    await _supabase.from('private_cards').update({
      'comment': privateComment,
    }).eq('post_id', postId);
  }

  // --- Decks (Deck management) ---

  // 仮のローカルストレージ（Supabaseテーブルがない場合のフォールバック用）
  static final List<DeckModel> _localDecks = [...initialMockDecks];

  Future<List<DeckModel>> fetchAllDecks() async {
    // 将来的にはここで _supabase.from('decks').select(...) を呼び出す
    // 現状はテーブルが未定義のため、初期モック＋追加分を返す
    await Future.delayed(const Duration(milliseconds: 500)); // 通信シミュレーション
    return _localDecks;
  }

  Future<void> createDeck({required String title}) async {
    // 将来的にはここで _supabase.from('decks').insert(...)
    await Future.delayed(const Duration(milliseconds: 500));
    
    final newDeck = DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      date: DateTime.now(),
      cards: [], // 新規作成時は空
      location: 'No Location Yet',
    );
    _localDecks.insert(0, newDeck);
  }

  Future<void> updateDeck({required String deckId, required String title}) async {
    // 将来的にはここで _supabase.from('decks').update({'title': title}).eq('id', deckId)
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _localDecks.indexWhere((d) => d.id == deckId);
    if (index >= 0) {
      final old = _localDecks[index];
      _localDecks[index] = DeckModel(
        id: old.id,
        title: title,
        date: old.date,
        cards: old.cards,
        location: old.location,
      );
    }
  }

  Future<void> addCardsToDeck({required String deckId, required List<ExperienceCardModel> newCards}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _localDecks.indexWhere((d) => d.id == deckId);
    if (index >= 0) {
      final old = _localDecks[index];
      // 重複を防ぐため、既存にないIDのカードのみ追加
      final existingIds = old.cards.map((c) => c.id).toSet();
      final cardsToAdd = newCards.where((c) => !existingIds.contains(c.id)).toList();
      
      final updatedCards = List<ExperienceCardModel>.from(old.cards)..addAll(cardsToAdd);
      
      _localDecks[index] = DeckModel(
        id: old.id,
        title: old.title,
        date: old.date,
        cards: updatedCards,
        location: old.location,
      );
    }
  }

  Future<void> removeCardFromDeck({required String deckId, required String cardId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _localDecks.indexWhere((d) => d.id == deckId);
    if (index >= 0) {
      final old = _localDecks[index];
      final updatedCards = old.cards.where((c) => c.id != cardId).toList();
      
      _localDecks[index] = DeckModel(
        id: old.id,
        title: old.title,
        date: old.date,
        cards: updatedCards,
        location: old.location,
      );
    }
  }

  Future<void> deleteDeck(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _localDecks.removeWhere((d) => d.id == deckId);
  }
}
