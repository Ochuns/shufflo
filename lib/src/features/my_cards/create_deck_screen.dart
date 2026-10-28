import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/decks_provider.dart';

class CreateDeckScreen extends ConsumerStatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  ConsumerState<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends ConsumerState<CreateDeckScreen> {
  final _titleController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(decksProvider.notifier).createDeck(title);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('デッキの作成に失敗しました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AizuColors.kinari,
      appBar: AppBar(
        backgroundColor: AizuColors.kinari,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: AizuColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '新しいデッキを作成',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AizuColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  '作成',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'デッキ名',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AizuColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AizuColors.textPrimary, fontSize: 18),
              decoration: InputDecoration(
                hintText: '例：会津若松めぐり 2026',
                hintStyle: TextStyle(color: AizuColors.textSecondary),
                filled: true,
                fillColor: AizuColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AizuColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            Text(
              'このデッキに体験カードをまとめていきます。',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AizuColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
