import 'package:flutter/material.dart';
import '../../models/experience_card_model.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  ExperienceCategory? _selectedCategory;
  double _rating = 3.0;

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
            // Image Upload Placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Upload Photo', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Title Input
            TextFormField(
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Awesome Cafe'),
            ),
            const SizedBox(height: 16),
            
            // Comment Input
            TextFormField(
              decoration: const InputDecoration(labelText: 'Comment', hintText: 'How was it?'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Category Dropdown
            DropdownButtonFormField<ExperienceCategory>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: _selectedCategory,
              items: ExperienceCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.label),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // Rating Selector
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _rating,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              label: _rating.toString(),
              activeColor: const Color(0xFFF59E0B),
              onChanged: (val) {
                setState(() {
                  _rating = val;
                });
              },
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            ElevatedButton(
              onPressed: () {
                // TODO: Save card MVP
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card Saved!')),
                );
              },
              child: const Text('Craft Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
