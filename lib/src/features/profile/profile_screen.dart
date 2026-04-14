import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/cards_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            'Profile',
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
                    ],
                  ),
                ),
                // Stats Row
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(cards.length.toString(), 'Cards'),
                      _buildStatItem('3', 'Decks'),
                      _buildStatItem('12', 'Friends'),
                    ],
                  ),
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
                      Tab(icon: Icon(LucideIcons.user, size: 20), text: 'Info'),
                      Tab(icon: Icon(LucideIcons.heart, size: 20), text: 'Favorites'),
                      Tab(icon: Icon(LucideIcons.users, size: 20), text: 'Friends'),
                    ],
                  ),
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildProfileInfoTab(),
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

  Widget _buildProfileInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoCard('Bio', 'I love capturing the sounds and visuals of the city. Every card is a new story.'),
        const SizedBox(height: 16),
        _buildInfoCard('Location', 'Tokyo, Japan'),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.tag, size: 48, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text(
            'No Tagged Favorites Yet',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tag your favorite cards to see them here.',
            style: GoogleFonts.inter(color: Colors.grey.shade700),
          ),
        ],
      ),
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

  Widget _buildInfoCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
        ],
      ),
    );
  }
}
