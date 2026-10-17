import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/cards_provider.dart';
import '../../models/pinned_cards_provider.dart';
import '../../models/supabase_repository.dart';
import '../../models/social_models.dart';
import '../../models/social_providers.dart';
import '../../models/social_repository.dart';
import '../../common_widgets/tcg_card_view.dart';
import '../social/timeline_list.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showStats = false;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final myId = ref.watch(supabaseRepositoryProvider).currentUserId;
    final myProfile = ref.watch(myProfileProvider).value;
    final friendsCount = ref.watch(friendsProvider).value?.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            'Shufflo',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.search, color: Colors.white),
              tooltip: 'ユーザーを探す',
              onPressed: () => context.push('/user_search'),
            ),
            Consumer(builder: (context, ref, _) {
              final unread = ref.watch(unreadCountProvider).value ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(LucideIcons.bell, color: Colors.white),
                ),
                tooltip: '通知',
                onPressed: () => context.push('/notifications'),
              );
            }),
            IconButton(
              icon: const Icon(LucideIcons.settings, color: Colors.white),
              onPressed: () => context.push('/account'),
            ),
          ],
        ),
        body: cardsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (cards) {
            return Column(
              children: [
                // Profile Header
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundImage: CachedNetworkImageProvider(
                          myProfile?.displayAvatar ?? 'https://i.pravatar.cc/300',
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myProfile?.username ?? '...',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (myProfile?.bio != null && myProfile!.bio!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                myProfile.bio!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditProfileSheet(context, myProfile),
                        icon: const Icon(LucideIcons.pencil, color: Colors.white, size: 20),
                        tooltip: 'プロフィール編集',
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showStats = !_showStats;
                          });
                        },
                        icon: Icon(
                          _showStats ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stats Drawer
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _showStats
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('${myProfile?.postCount ?? 0}', '投稿'),
                              GestureDetector(
                                onTap: () => context.push('/friends'),
                                child: _buildStatItem('${friendsCount ?? 0}', '友達'),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity, height: 16), // 閉じている時も少しだけ余白を残す
                ),
                // Tab Bar
                Container(
                  color: Colors.black,
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade700,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.dynamic_feed, size: 20), text: 'タイムライン'),
                      Tab(icon: Icon(LucideIcons.heart, size: 20), text: 'お気に入り'),
                    ],
                  ),
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      myId == null
                          ? const SizedBox.shrink()
                          : TimelineList(userId: myId),
                      _buildFavoritesTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20, 
            fontWeight: FontWeight.w700, 
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    final pinnedIdsAsync = ref.watch(pinnedCardsProvider);
    final cardsAsync = ref.watch(cardsProvider);

    return pinnedIdsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(
        child: Text('Error loading favorites', style: TextStyle(color: Colors.red)),
      ),
      data: (pinnedIds) => cardsAsync.when(
        data: (cards) {
          final pinnedCards = cards.where((c) => pinnedIds.contains(c.id)).toList();

          if (pinnedCards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.tag, size: 48, color: Colors.grey.shade800),
                  const SizedBox(height: 16),
                  Text(
                    'No Pinned Cards Yet',
                    style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pin cards from their detail screen to show them here.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65, // TcgCardView is 6/9.5
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: pinnedCards.length,
            itemBuilder: (context, index) {
              final card = pinnedCards[index];
              return GestureDetector(
                onTap: () => context.push('/card_detail', extra: card),
                child: TcgCardView(model: card, isCompact: true),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(
          child: Text('Error loading favorites', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context, UserProfile? profile) async {
    final usernameCtrl = TextEditingController(text: profile?.username ?? '');
    final bioCtrl = TextEditingController(text: profile?.bio ?? '');
    final avatarCtrl = TextEditingController(text: profile?.avatarUrl ?? '');
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (c, setSheet) {
            Future<void> save() async {
              setSheet(() => saving = true);
              try {
                await ref.read(socialRepositoryProvider).updateMyProfile(
                      username: usernameCtrl.text,
                      bio: bioCtrl.text,
                      avatarUrl: avatarCtrl.text,
                    );
                ref.invalidate(myProfileProvider);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              } catch (_) {
                setSheet(() => saving = false);
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(
                      content: Text('保存に失敗しました（ユーザー名の重複などをご確認ください）')));
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(c).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('プロフィール編集',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(labelText: 'ユーザー名')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: bioCtrl,
                      maxLength: 140,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '自己紹介（140字以内）')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: avatarCtrl,
                      decoration: const InputDecoration(labelText: 'アバター画像URL')),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: saving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    usernameCtrl.dispose();
    bioCtrl.dispose();
    avatarCtrl.dispose();
  }
}
