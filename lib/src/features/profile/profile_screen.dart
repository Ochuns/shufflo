import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/cards_provider.dart';
import '../../models/pinned_cards_provider.dart';
import '../../common_widgets/tcg_card_view.dart';
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
              icon: const Icon(LucideIcons.settings, color: Colors.white),
              onPressed: () {},
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
                      const CircleAvatar(
                        radius: 35,
                        backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/300'),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Creative Editor',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@experience_crafter',
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
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
                              _buildStatItem(cards.length.toString(), 'Cards'),
                              _buildStatItem('3', 'Decks'),
                              _buildStatItem('12', 'Friends'),
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
                      Tab(icon: Icon(LucideIcons.heart, size: 20), text: 'Favorites'),
                      Tab(icon: Icon(LucideIcons.users, size: 20), text: 'Friends'),
                    ],
                  ),
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildFavoritesTab(),
                      _buildFriendSearchTab(),
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
    
    // pinnedIdsがまだロード中の場合は空セットとして扱い、ちらつきを防ぐ
    final pinnedIds = pinnedIdsAsync.value ?? {};

    return cardsAsync.when(
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
            crossAxisCount: 3,
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
      error: (e, st) => const Center(child: Text('Error loading favorites', style: TextStyle(color: Colors.red))),
    );
  }

  Widget _buildFriendSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search friends by ID...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(LucideIcons.search, size: 20, color: Colors.grey.shade600),
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Icon(LucideIcons.userPlus, size: 48, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text(
            'Find Your Friends',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
