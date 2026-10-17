import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../models/theme_models.dart';
import '../../models/theme_providers.dart';

/// テーマ別コレクション一覧（§5.4）。進捗率の高い順・縦並び・コンパクト表示。
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(themesProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                '会津めぐり',
                style: GoogleFonts.outfit(
                    fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            Expanded(
              child: themesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('テーマを読み込めませんでした')),
                data: (themes) {
                  if (themes.isEmpty) {
                    return const Center(
                      child: Text('まだテーマがねぇな', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(themesProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: themes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ThemeTile(theme: themes[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme});
  final ThemeSummary theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/theme', extra: theme.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    theme.name,
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                if (theme.isComplete)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.verified, color: Colors.amber, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: theme.progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(
                    theme.isComplete ? Colors.amber : Colors.pinkAccent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${theme.collectedCount} / ${theme.targetCount}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                if (theme.rewardTitle != null && theme.rewardTitle!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(theme.rewardTitle!,
                          style: const TextStyle(color: Colors.amber, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
