import 'package:flutter/material.dart';
import '../../models/experience_card_model.dart';
import '../../common_widgets/tcg_card_view.dart';

class CardDetailScreen extends StatelessWidget {
  final ExperienceCardModel model;

  const CardDetailScreen({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // ダークな宇宙的背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TcgCardView(model: model),
          ),
        ),
      ),
    );
  }
}
