import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../models/experience_card_model.dart';
import '../../models/cards_provider.dart';
import '../../models/decks_provider.dart';
import '../../models/visit_models.dart';
import '../../models/visit_repository.dart';
import '../../utils/exif_utils.dart';
import 'widgets/tcg_card_editor_components.dart';

class PostScreen extends ConsumerStatefulWidget {
  /// 訪問確認フローから来た場合のコンテキスト（店舗・確認ID・撮影写真）。
  /// null の場合は通常のカード作成（GPS/QR検証なし）。
  const PostScreen({super.key, this.visitContext});

  final VisitContext? visitContext;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _titleController = TextEditingController();
  final _publicCommentController = TextEditingController();
  final _privateCommentController = TextEditingController();
  
  ExperienceCategory? _selectedCategory;
  double _rating = 3.0;

  String? _publicImagePath;
  String? _privateImagePath;

  final ImagePicker _picker = ImagePicker();

  double? _latitude;
  double? _longitude;

  String? _selectedDeckId;
  bool _isLoading = false;

  double _targetAngle = 0.0;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    final vc = widget.visitContext;
    if (vc != null) {
      // 訪問確認フロー: 撮影写真・店舗位置・店名を自動入力
      _publicImagePath = vc.capturedPhotoPath;
      _latitude = vc.latitude;
      _longitude = vc.longitude;
      _titleController.text = vc.storeName;
      _selectedCategory = ExperienceCategory.restaurant;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _publicCommentController.dispose();
    _privateCommentController.dispose();
    super.dispose();
  }

  void _toggleFlip({bool swipeRight = true}) {
    setState(() {
      _targetAngle += swipeRight ? -pi : pi;
      _isFront = ( _targetAngle / pi ).round() % 2 == 0;
    });
  }

  Future<void> _pickImage(bool isPublic) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, requestFullMetadata: true);
    if (image != null) {
      if (isPublic) {
        final bytes = await image.readAsBytes();
        final loc = await ExifUtils.getLocationFromImage(bytes);
        setState(() {
          _publicImagePath = image.path;
          _latitude = loc?['latitude'];
          _longitude = loc?['longitude'];
        });
      } else {
        setState(() {
          _privateImagePath = image.path;
        });
      }
    }
  }

  Future<void> _submitCard() async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルとカテゴリを入力してけさい。')));
      return;
    }

    if (_publicImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('公開用の写真を選んでけさい。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final postId = await ref.read(cardsProvider.notifier).submitPost(
        title: _titleController.text,
        category: _selectedCategory!,
        rating: _rating,
        publicComment: _publicCommentController.text.isNotEmpty ? _publicCommentController.text : 'No comment.',
        privateComment: _privateCommentController.text.isNotEmpty ? _privateCommentController.text : 'No comment.',
        publicImagePath: _publicImagePath,
        privateImagePath: _privateImagePath,
        latitude: _latitude,
        longitude: _longitude,
        deckId: _selectedDeckId,
      );

      // 訪問確認フロー: 保存成功後にテーマ進捗を更新（カード保存前には増えない）
      final vc = widget.visitContext;
      if (vc != null) {
        try {
          await ref.read(visitRepositoryProvider).completeThemeVisit(
                verificationId: vc.verificationId,
                postId: postId,
              );
        } catch (e) {
          debugPrint('completeThemeVisit failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('カードは保存できたが、テーマ進捗の更新に失敗したよ。')),
            );
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カードを作成して、テーマ進捗を更新したぞ！')),
        );
        context.pop(); // 訪問フローは作成画面を閉じて戻る
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('カードを作成したぞ！')));

      // Reset Form（通常フロー）
      setState(() {
        _titleController.clear();
        _publicCommentController.clear();
        _privateCommentController.clear();
        _selectedCategory = null;
        _selectedDeckId = null;
        _rating = 3.0;
        _publicImagePath = null;
        _privateImagePath = null;
        if (!_isFront) {
          _isFront = true;
          _targetAngle = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: ' + e.toString())));
      debugPrint('Submit Error: ' + e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);

    return Scaffold(
      backgroundColor: AizuColors.kinari,
      appBar: AppBar(
        title: const Text('カードをつくる', style: TextStyle(fontWeight: FontWeight.w700, color: AizuColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AizuColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== 3D Flip Card Editor =====
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
                    bool swipeRight = details.primaryVelocity! > 0;
                    _toggleFlip(swipeRight: swipeRight);
                  }
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _targetAngle),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    bool isFrontSide = (value / pi).round() % 2 == 0;

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015) 
                        ..rotateY(value),
                      child: isFrontSide
                          ? TcgCardEditorFront(
                              titleController: _titleController,
                              commentController: _publicCommentController,
                              selectedCategory: _selectedCategory ?? ExperienceCategory.other,
                              rating: _rating,
                              imagePath: _publicImagePath,
                              onPickImage: () => _pickImage(true),
                            )
                          : Transform(
                              // 裏面はY軸でもう180度回転させて鏡文字を防ぐ
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: TcgCardEditorBack(
                                titleController: _titleController,
                                commentController: _privateCommentController,
                                selectedCategory: _selectedCategory ?? ExperienceCategory.other,
                                rating: _rating,
                                imagePath: _privateImagePath,
                                onPickImage: () => _pickImage(false),
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (_isFront && _publicImagePath != null && _latitude == null)
                const Center(
                  child: Text('⚠️ Public Photo has no location data.', style: TextStyle(color: Colors.amber, fontSize: 12)),
                ),
              const SizedBox(height: 8),

              // ===== Controls Below Card =====
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEF5350), width: 3), // 淡めの赤でマーカーライン
                        ),
                      ),
                      child: Text(
                        _isFront ? 'Editing: PUBLIC SIDE' : 'Editing: PRIVATE SIDE',
                        style: const TextStyle(
                          color: AizuColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isFront ? 'This side will be visible on the feed.' : 'This side is your personal secret journal.',
                      style: const TextStyle(
                        color: AizuColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => _toggleFlip(swipeRight: true),
                      icon: const Icon(LucideIcons.repeat),
                      label: Text(_isFront ? 'Flip to Private Side' : 'Flip to Public Side'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AizuColors.surfaceAlt,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // UI Element for picking category (Restored)
              DropdownButtonFormField<ExperienceCategory>(
                dropdownColor: AizuColors.surfaceAlt,
                style: const TextStyle(color: AizuColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'カテゴリ',
                  labelStyle: const TextStyle(color: AizuColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AizuColors.textPrimary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AizuColors.textPrimary.withOpacity(0.1)),
                  ),
                ),
                value: _selectedCategory,
                items: ExperienceCategoryExtension.foodCategories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat.label));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 16),

              // UI Element for rating (Restored)
              const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600, color: AizuColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = starValue.toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        starValue <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amberAccent,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              decksAsync.when(
                data: (decks) {
                  if (decks.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    dropdownColor: AizuColors.surfaceAlt,
                    style: const TextStyle(color: AizuColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Add to Deck (Optional)',
                      labelStyle: const TextStyle(color: AizuColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AizuColors.textPrimary.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AizuColors.textPrimary.withOpacity(0.1)),
                      ),
                    ),
                    value: _selectedDeckId,
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('None')),
                      ...decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))).toList(),
                    ],
                    onChanged: (val) => setState(() => _selectedDeckId = val),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Failed to load decks', style: TextStyle(color: Colors.red)),
              ),
              
              const SizedBox(height: 32),
              
              _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AizuColors.textPrimary))
                  : ElevatedButton(
                      onPressed: _submitCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Create Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
