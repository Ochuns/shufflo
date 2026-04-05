import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/cards_provider.dart';
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

  Future<void> _pickImage(bool isPublic) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isPublic) {
          _publicImagePath = image.path;
        } else {
          _privateImagePath = image.path;
        }
      });
    }
  }

  void _submitCard() {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out the title and category.')));
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch.toString();

    // Create Public Card
    final publicCard = ExperienceCardModel(
      id: "pub_\$now",
      title: _titleController.text,
      imageUrl: _publicImagePath != null ? '' : 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c', // fallback
      localImagePath: _publicImagePath,
      rating: _rating,
      category: _selectedCategory!,
      comment: _publicCommentController.text.isNotEmpty ? _publicCommentController.text : 'No comment.',
      authorName: 'Creative Editor',
      authorAvatarUrl: 'https://i.pravatar.cc/300',
      isPublic: true,
    );

    // Create Private Card
    final privateCard = ExperienceCardModel(
      id: "priv_\$now",
      title: _titleController.text,
      imageUrl: _privateImagePath != null ? '' : 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e', // fallback
      localImagePath: _privateImagePath,
      rating: _rating,
      category: _selectedCategory!,
      comment: _privateCommentController.text.isNotEmpty ? _privateCommentController.text : 'No comment.',
      authorName: 'Creative Editor',
      authorAvatarUrl: 'https://i.pravatar.cc/300',
      isPublic: false,
    );

    final cardsNotifier = ref.read(cardsProvider.notifier);
    cardsNotifier.state = [...cardsNotifier.state, publicCard, privateCard];

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cards created successfully!')));
    
    // Reset Form
    setState(() {
      _titleController.clear();
      _publicCommentController.clear();
      _privateCommentController.clear();
      _selectedCategory = null;
      _rating = 3.0;
      _publicImagePath = null;
      _privateImagePath = null;
    });
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 24),
            
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
            
            ElevatedButton(
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
