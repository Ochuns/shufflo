import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/experience_card_model.dart';
import '../../models/cards_provider.dart';
import '../../models/supabase_repository.dart';
import '../../models/deck_model.dart';
import '../../models/decks_provider.dart';
import '../../common_widgets/tcg_card_view.dart';

class CardDetailScreen extends ConsumerWidget {
  final ExperienceCardModel model;
  final bool showAppBar;

  const CardDetailScreen({
    super.key, 
    required this.model,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // プロバイダーから最新のリストを取得し、このカードの最新情報を探す
    final cardsAsync = ref.watch(cardsProvider);
    final decksAsync = ref.watch(decksProvider);
    
    return cardsAsync.when(
      data: (cards) {
        // IDが一致する最新のモデルを探す。見つからない場合は初期渡しのモデルをフォールバックとして使用
        final latestModel = cards.firstWhere(
          (c) => c.id == model.id,
          orElse: () => model,
        );
        
        final currentUserId = ref.watch(supabaseRepositoryProvider).currentUserId;
        final isOwner = latestModel.authorId == currentUserId;

        // このカードが所属しているデッキを探す
        final parentDeck = decksAsync.value?.where((d) => 
          d.cards.any((c) => c.id == latestModel.id || c.postId == latestModel.postId)
        ).firstOrNull;

        return Scaffold(
          backgroundColor: const Color(0xFF121212), 
          appBar: showAppBar ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (parentDeck != null)
                IconButton(
                  icon: const Icon(Icons.layers_outlined),
                  onPressed: () => context.push('/deck_playback', extra: parentDeck),
                  tooltip: 'View in Deck',
                ),
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditSheet(context, ref, latestModel),
                  tooltip: 'Edit Card',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _showDeleteDialog(context, ref, latestModel),
                  tooltip: 'Delete Card',
                ),
                const SizedBox(width: 8),
              ],
            ],
          ) : null,
          extendBodyBehindAppBar: true,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24, 
                  right: 24, 
                  bottom: 16,
                  top: showAppBar ? 16 : 72, // AppBarがない（デッキ内）場合は上部余白を取る
                ),
                child: TcgCardView(model: latestModel),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ExperienceCardModel targetModel) {
    final canDelete = targetModel.postId != null;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Card?', style: TextStyle(color: Colors.white)),
        content: Text(
          canDelete
              ? 'This card and its public posts will be moved to your history and not be visible to others. It will also be removed from any decks it belongs to.'
              : 'This card cannot be deleted because it does not have a post ID.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: canDelete
                ? () async {
                    final postId = targetModel.postId;
                    if (postId == null) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to delete this card because its post ID is missing.'),
                          ),
                        );
                      }
                      return;
                    }

                    await ref.read(cardsProvider.notifier).deleteCard(postId);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext); // Close dialog
                      context.pop(); // Go back from detail
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Card deleted (archived).')),
                      );
                    }
                  }
                : null,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, ExperienceCardModel targetModel) {
    final titleController = TextEditingController(text: targetModel.title);
    final publicCommentController = TextEditingController(text: targetModel.comment);
    
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
            const Text('Edit Card', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
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
                prefixIcon: const Icon(Icons.title, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: publicCommentController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Post Detail',
                labelStyle: const TextStyle(color: Colors.white70),
                alignLabelWithHint: true,
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
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.notes, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (targetModel.postId != null) {
                  await ref.read(cardsProvider.notifier).updateCard(
                    postId: targetModel.postId!,
                    title: titleController.text,
                    category: targetModel.category,
                    rating: targetModel.rating,
                    publicComment: publicCommentController.text,
                    privateComment: publicCommentController.text, 
                  );
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
}
