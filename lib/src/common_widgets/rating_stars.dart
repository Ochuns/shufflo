import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16.0,
    this.color = const Color(0xFFF59E0B), // Amber color
  });

  @override
  Widget build(BuildContext context) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < fullStars; i++)
          Icon(Icons.star_rounded, size: size, color: color),
        if (hasHalfStar)
          Icon(Icons.star_half_rounded, size: size, color: color),
        for (int i = 0; i < emptyStars; i++)
          Icon(Icons.star_outline_rounded, size: size, color: color),
      ],
    );
  }
}
