import 'package:flutter/material.dart';
import '../models/experience_card_model.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryTag extends StatelessWidget {
  final ExperienceCategory category;
  final double fontSize;
  final EdgeInsets padding;

  const CategoryTag({
    super.key,
    required this.category,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category.label,
        style: GoogleFonts.inter(
          color: category.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
