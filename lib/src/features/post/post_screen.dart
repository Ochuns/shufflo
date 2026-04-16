import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/experience_card_model.dart';
import '../../models/cards_provider.dart';
import '../../models/decks_provider.dart';
import '../../utils/exif_utils.dart';
import 'package:go_router/go_router.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key});

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

  String? _selectedDeckId;
  bool _isLoading = false;

  Future<void> _submitCard() async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out the title and category.')));
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

  Widget _buildImageUploader(String label, String? imagePath, bool isPublic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(isPublic),
          child: Container(
            height: 120, // 以前は180。高さを下げてより横長な（アスペクト比の大きい）エリアにする
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 2),
              image: imagePath != null ? DecorationImage(image: FileImage(File(imagePath)), fit: BoxFit.cover) : null,
            ),
            child: imagePath == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Upload Image', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  )
                : null,
          ),
        ),
        if (isPublic && imagePath != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _latitude != null ? Icons.location_on : Icons.location_off,
                size: 16,
                color: _latitude != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _latitude != null 
                  ? '📍 位置情報を写真から取得しました' 
                  : '⚠️ 写真に位置情報が見つかりません',
                style: TextStyle(
                  fontSize: 12,
                  color: _latitude != null ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Card', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageUploader('Public Photo', _publicImagePath, true),
            const SizedBox(height: 24),
            
            _buildImageUploader('Private Photo', _privateImagePath, false),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Awesome Cafe'),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _publicCommentController,
              decoration: const InputDecoration(labelText: 'Public Comment', hintText: 'For everyone to see'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _privateCommentController,
              decoration: const InputDecoration(labelText: 'Private Comment', hintText: 'Your secret memories'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<ExperienceCategory>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: _selectedCategory,
              items: ExperienceCategory.values.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat.label));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),

            decksAsync.when(
              data: (decks) {
                if (decks.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Add to Deck (Optional)',
                        hintText: 'Select a deck to add this card to',
                      ),
                      value: _selectedDeckId,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('None')),
                        ...decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))).toList(),
                      ],
                      onChanged: (val) => setState(() => _selectedDeckId = val),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Failed to load decks'),
            ),
            
            const SizedBox(height: 8),
            // ... Rating section ...
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
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
            
            _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitCard,
                    child: const Text('Create Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
