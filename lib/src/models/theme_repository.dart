import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme_models.dart';

final themeRepositoryProvider = Provider((ref) => ThemeRepository());

/// テーマ別コレクションのデータ層。
/// 進捗付与・報酬発行などの不変条件はサーバー側（RPC/RLS）で強制される。
class ThemeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// アクティブなテーマ一覧（進捗率の高い順、同率は sort_order 安定）。
  Future<List<ThemeSummary>> fetchThemes() async {
    final me = currentUserId;
    final List themes = await _supabase
        .from('themes')
        .select('id, name, sort_order, reward_title, reward_description')
        .eq('is_active', true)
        .order('sort_order');

    final List themeStores =
        await _supabase.from('theme_stores').select('theme_id, store_id');
    final targetCount = <String, int>{};
    for (final ts in themeStores) {
      final tid = ts['theme_id'];
      targetCount[tid] = (targetCount[tid] ?? 0) + 1;
    }

    final List cycles = me == null
        ? const []
        : await _supabase.from('theme_cycles').select('theme_id, cycle_number').eq('user_id', me);
    final cycleByTheme = {for (final c in cycles) c['theme_id']: c['cycle_number'] as int};

    final List progress = me == null
        ? const []
        : await _supabase
            .from('theme_progress')
            .select('theme_id, store_id, cycle_number')
            .eq('user_id', me);

    final result = themes.map<ThemeSummary>((t) {
      final tid = t['id'];
      final cyc = cycleByTheme[tid] ?? 1;
      final collected =
          progress.where((p) => p['theme_id'] == tid && p['cycle_number'] == cyc).length;
      return ThemeSummary(
        id: tid,
        name: t['name'] ?? '',
        sortOrder: t['sort_order'] ?? 0,
        rewardTitle: t['reward_title'],
        rewardDescription: t['reward_description'],
        targetCount: targetCount[tid] ?? 0,
        collectedCount: collected,
        cycleNumber: cyc,
      );
    }).toList();

    result.sort((a, b) {
      final c = b.progress.compareTo(a.progress);
      return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
    });
    return result;
  }

  /// テーマ詳細（店舗スロット）。
  Future<ThemeDetail> fetchThemeDetail(String themeId) async {
    final me = currentUserId;
    final theme = await _supabase
        .from('themes')
        .select('id, name, sort_order, reward_title, reward_description')
        .eq('id', themeId)
        .single();

    final List storeRows = await _supabase
        .from('theme_stores')
        .select('store_id, stores(id, name)')
        .eq('theme_id', themeId);

    final cycleRow = me == null
        ? null
        : await _supabase
            .from('theme_cycles')
            .select('cycle_number')
            .eq('user_id', me)
            .eq('theme_id', themeId)
            .maybeSingle();
    final cycle = (cycleRow?['cycle_number'] as int?) ?? 1;

    final List progress = me == null
        ? const []
        : await _supabase
            .from('theme_progress')
            .select('store_id, visited_records(post_id)')
            .eq('user_id', me)
            .eq('theme_id', themeId)
            .eq('cycle_number', cycle);

    final visitedPostByStore = <String, String?>{};
    for (final p in progress) {
      visitedPostByStore[p['store_id']] = p['visited_records']?['post_id'];
    }

    // 訪問済み店舗のカード画像を取得（post_id から解決）
    final visitedPostIds =
        visitedPostByStore.values.whereType<String>().toList();
    final imageByPost = await _fetchCardImagesByPost(visitedPostIds);

    final directory = await getApplicationDocumentsDirectory();
    final imagesDirPath = '${directory.path}/stored-images';

    final slots = storeRows.map<ThemeStoreSlot>((row) {
      final store = row['stores'];
      final storeId = row['store_id'];
      final visited = visitedPostByStore.containsKey(storeId);
      final postId = visitedPostByStore[storeId];
      final img = postId != null ? imageByPost[postId] : null;
      return ThemeStoreSlot(
        storeId: storeId,
        storeName: store?['name'] ?? '店舗',
        visited: visited,
        postId: postId,
        cardImageUrl: img?['image_url'],
        cardLocalPath: img?['local_image_path'] != null
            ? '$imagesDirPath/${img!['local_image_path']}'
            : null,
      );
    }).toList();

    final targetCount = storeRows.length;
    final collectedCount = visitedPostByStore.length;

    return ThemeDetail(
      summary: ThemeSummary(
        id: theme['id'],
        name: theme['name'] ?? '',
        sortOrder: theme['sort_order'] ?? 0,
        rewardTitle: theme['reward_title'],
        rewardDescription: theme['reward_description'],
        targetCount: targetCount,
        collectedCount: collectedCount,
        cycleNumber: cycle,
      ),
      slots: slots,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchCardImagesByPost(List<String> postIds) async {
    final map = <String, Map<String, dynamic>>{};
    if (postIds.isEmpty) return map;
    final List pub = await _supabase
        .from('public_cards')
        .select('post_id, image_url, local_image_path')
        .inFilter('post_id', postIds);
    for (final r in pub) {
      map[r['post_id']] = {'image_url': r['image_url'], 'local_image_path': r['local_image_path']};
    }
    final List priv = await _supabase
        .from('private_cards')
        .select('post_id, image_url, local_image_path')
        .inFilter('post_id', postIds);
    for (final r in priv) {
      map.putIfAbsent(r['post_id'],
          () => {'image_url': r['image_url'], 'local_image_path': r['local_image_path']});
    }
    return map;
  }

  /// 報酬を受け取る（サイクル完成時のみサーバーが許可。冪等）。
  Future<void> claimReward(String themeId) async {
    await _supabase.rpc('claim_theme_reward', params: {'p_theme_id': themeId});
  }
}
