import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_card_model.dart';
import 'package:path/path.dart' as p;

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

    final fileName = "\${DateTime.now().millisecondsSinceEpoch}_local.jpg";
    final ext = p.extension(localPath);
    final fullPath = "\${DateTime.now().millisecondsSinceEpoch}\$ext";
    
    try {
      await _supabase.storage.from(bucket).upload(fullPath, file);
      return _supabase.storage.from(bucket).getPublicUrl(fullPath);
    } catch (e) {
      // バケットがない、認証エラーなどのMVP挙動でフォールバック
      return null;
    }
  }

  // 3. すべての関連テーブルに新しいカード(Post)を追加
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
    await _ensureUserExists();

    final userId = currentUserId!;
    
    // 画像アップロード
    final pubImageUrl = await uploadImage(publicImagePath, 'card-images') ?? 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=600&q=80';
    final privImageUrl = await uploadImage(privateImagePath, 'card-images') ?? 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600&q=80';

    // MVP fallback (渋谷駅周辺) if no location
    final lat = latitude ?? 35.6580;
    final lon = longitude ?? 139.7016;
    final locName = latitude != null ? 'Extracted Location' : 'Unknown Location (Default)';

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
  }

  // 4. Public/Privateカードの一括取得
  Future<List<ExperienceCardModel>> fetchAllCards() async {
    final List<ExperienceCardModel> cards = [];
    final userId = currentUserId;

    // Public Cards
    final pubRes = await _supabase.from('public_cards').select('*, users(username, avatar_url)');
    for (var row in pubRes) {
      cards.add(ExperienceCardModel(
        id: row['id'],
        title: row['title'] ?? 'Untitled',
        imageUrl: row['image_url'] ?? '',
        rating: (row['rating'] ?? 3).toDouble(),
        category: ExperienceCategory.values.firstWhere((e) => e.name == row['category'], orElse: () => ExperienceCategory.other),
        comment: row['comment'] ?? '',
        authorName: row['users'] != null ? row['users']['username'] : 'Explorer',
        authorAvatarUrl: row['users'] != null ? row['users']['avatar_url'] : 'https://i.pravatar.cc/300',
        isPublic: true,
      ));
    }

    if (userId != null) {
      // Private Cards for the specific user
      final privRes = await _supabase.from('private_cards').select('*, posts!inner(title, category, rating), users(username, avatar_url)').eq('user_id', userId);
      for (var row in privRes) {
        final postData = row['posts'];
        cards.add(ExperienceCardModel(
          id: row['id'],
          title: postData?['title'] ?? 'Untitled',
          imageUrl: row['image_url'] ?? '',
          rating: (postData?['rating'] ?? 3).toDouble(),
          category: ExperienceCategory.values.firstWhere((e) => e.name == postData?['category'], orElse: () => ExperienceCategory.other),
          comment: row['comment'] ?? '',
          authorName: row['users'] != null ? row['users']['username'] : 'Explorer',
          authorAvatarUrl: row['users'] != null ? row['users']['avatar_url'] : 'https://i.pravatar.cc/300',
          isPublic: false,
        ));
      }
    }

    return cards;
  }
}
