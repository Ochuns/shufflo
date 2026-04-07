import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/experience_card_model.dart';
import '../../models/cards_provider.dart';
import '../../models/supabase_repository.dart';
import '../../common_widgets/tcg_card_view.dart';

class CardDetailScreen extends ConsumerWidget {
  final ExperienceCardModel model;

  const CardDetailScreen({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // プロバイダーから最新のリストを取得し、このカードの最新情報を探す
    final cardsAsync = ref.watch(cardsProvider);
    
    return cardsAsync.when(
      data: (cards) {
        // IDが一致する最新のモデルを探す。見つからない場合は初期渡しのモデルをフォールバックとして使用
        final latestModel = cards.firstWhere(
          (c) => c.id == model.id,
          orElse: () => model,
        );
        
        final currentUserId = ref.watch(supabaseRepositoryProvider).currentUserId;
        final isOwner = latestModel.authorId == currentUserId;

        return Scaffold(
          backgroundColor: const Color(0xFF121212), 
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
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
          ),
          extendBodyBehindAppBar: true,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ExperienceCardModel targetModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Card?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This card and its public posts will be moved to your history and not be visible to others. This action can be undone later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (targetModel.postId != null) {
                await ref.read(cardsProvider.notifier).deleteCard(targetModel.postId!);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back from detail
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card deleted (archived).')),
                  );
                }
              }
            },
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
    // Ideally, for private cards, we should fetch the original post details or maintain the private comment in the model.
    // Since our model is combined, let's assume 'comment' currently holds the context-relevant comment.
    // For now, in this MVP, we'll edit title and the primary comment.
    
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
                    privateComment: publicCommentController.text, // Simplified for MVP
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
