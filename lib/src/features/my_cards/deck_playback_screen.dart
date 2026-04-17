import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/deck_model.dart';
import '../../models/decks_provider.dart';
import '../../models/cards_provider.dart';
import '../../models/experience_card_model.dart';
import '../explore/card_detail_screen.dart';

class DeckPlaybackScreen extends ConsumerStatefulWidget {
  final DeckModel deck;

  const DeckPlaybackScreen({super.key, required this.deck});

  @override
  ConsumerState<DeckPlaybackScreen> createState() => _DeckPlaybackScreenState();
}

class _DeckPlaybackScreenState extends ConsumerState<DeckPlaybackScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // プロバイダーから最新のデッキ情報を取得
    final decksAsync = ref.watch(decksProvider);
    final latestDeck = decksAsync.value?.cast<DeckModel?>().firstWhere(
      (d) => d?.id == widget.deck.id,
      orElse: () => widget.deck,
    ) ?? widget.deck;

    if (latestDeck.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(latestDeck.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditSheet(context, latestDeck),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteDialog(context, latestDeck),
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("This deck is empty.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text("Create a new card from the camera button\nand select this deck to add it.", 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. PageView for swiping through cards
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: latestDeck.cards.length,
            itemBuilder: (context, index) {
              final card = latestDeck.cards[index];
              return CardDetailScreen(
                model: card,
                showAppBar: false, // カード単体のAppBarは非表示にし、Deck全体のアクションに専念させる
              );
            },
          ),

          // 2. Journey Progress Indicator (Timeline at the top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: List.generate(latestDeck.cards.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: index <= _currentIndex ? Colors.white : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          
          // 3. Deck Custom Top Bar (Back, Title, Actions)
          Positioned(
            top: MediaQuery.of(context).padding.top + 24, // 戻るボタンの上に少し広めのマージンを確保
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   // Back Button (Left)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back, 
                        color: Colors.white, 
                        size: 28,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                      onPressed: () => context.pop(),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  // Title (Center)
                  Text(
                    latestDeck.title,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.2,
                      fontSize: 18,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Actions (Right)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined, 
                            color: Colors.white, 
                            size: 24,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                          onPressed: () => _showEditSheet(context, latestDeck),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline, 
                            color: Colors.white, 
                            size: 24,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                          onPressed: () => _showDeleteDialog(context, latestDeck),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, DeckModel targetDeck) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Deck?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this deck? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(decksProvider.notifier).deleteDeck(targetDeck.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext); // Close dialog
                context.pop(); // Go back to list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deck deleted.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, DeckModel targetDeck) {
    final titleController = TextEditingController(text: targetDeck.title);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Deck Title', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(LucideIcons.type, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  await ref.read(decksProvider.notifier).updateDeck(targetDeck.id, newTitle);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}


