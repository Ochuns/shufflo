import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/experience_card_model.dart';
import '../../models/cards_provider.dart';
import '../../models/decks_provider.dart';
import '../../utils/exif_utils.dart';
import 'widgets/tcg_card_editor_components.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key});

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> with SingleTickerProviderStateMixin {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out the title and category.')));
      return;
    }

    if (_publicImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a public photo.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(cardsProvider.notifier).submitPost(
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cards created successfully!')));
      
      // Reset Form
      setState(() {
        _titleController.clear();
        _publicCommentController.clear();
        _privateCommentController.clear();
        _selectedCategory = null;
        _selectedDeckId = null;
        _rating = 3.0;
        _publicImagePath = null;
        _privateImagePath = null;
        if (!_isFront) _toggleFlip(swipeRight: true); // 表面に戻す
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ' + e.toString())));
      debugPrint('Submit Error: ' + e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Wrap(
              children: ExperienceCategory.values.map((cat) {
                return ListTile(
                  leading: Icon(Icons.star_outline, color: Colors.amberAccent), // Generic icon for picker
                  title: Text(cat.label, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Design Card', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    Text(
                      _isFront ? 'Editing: PUBLIC SIDE' : 'Editing: PRIVATE SIDE',
                      style: TextStyle(
                        color: _isFront ? Colors.lightBlueAccent : Colors.purpleAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isFront ? 'This side will be visible on the feed.' : 'This side is your personal secret journal.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => _toggleFlip(swipeRight: true),
                      icon: const Icon(LucideIcons.repeat),
                      label: Text(_isFront ? 'Flip to Private Side' : 'Flip to Public Side'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // UI Element for picking category (Restored)
              DropdownButtonFormField<ExperienceCategory>(
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                value: _selectedCategory,
                items: ExperienceCategory.values.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat.label));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 16),

              // UI Element for rating (Restored)
              const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
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
                        color: const Color(0xFFFF6B6B),
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
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Add to Deck (Optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                  ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                  : ElevatedButton(
                      onPressed: _submitCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent.shade700,
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
