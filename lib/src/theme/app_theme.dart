import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'aizu_colors.dart';

class AppTheme {
  /// 会津らしさ × モダン のライトテーマ（生成り背景 / 赤べこ赤 / 会津木綿藍）。
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AizuColors.akabeko,
        onPrimary: AizuColors.textOnDark,
        secondary: AizuColors.aizuIndigo,
        onSecondary: AizuColors.textOnDark,
        surface: AizuColors.surface,
        onSurface: AizuColors.textPrimary,
        surfaceContainerHighest: AizuColors.surfaceAlt,
        error: AizuColors.danger,
      ),
      scaffoldBackgroundColor: AizuColors.kinari,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme)
          .apply(bodyColor: AizuColors.textPrimary, displayColor: AizuColors.textPrimary)
          .copyWith(
            displayLarge: GoogleFonts.outfit(textStyle: base.textTheme.displayLarge, color: AizuColors.textPrimary),
            displayMedium: GoogleFonts.outfit(textStyle: base.textTheme.displayMedium, color: AizuColors.textPrimary),
            displaySmall: GoogleFonts.outfit(textStyle: base.textTheme.displaySmall, color: AizuColors.textPrimary),
            headlineMedium: GoogleFonts.outfit(textStyle: base.textTheme.headlineMedium, color: AizuColors.textPrimary),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AizuColors.kinari,
        foregroundColor: AizuColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AizuColors.border, width: 1),
        ),
        color: AizuColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AizuColors.akabeko,
          foregroundColor: AizuColors.textOnDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AizuColors.akabeko,
          foregroundColor: AizuColors.textOnDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AizuColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AizuColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AizuColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AizuColors.akabeko, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AizuColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: Colors.white,
        surface: Color(0xFF141414),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: Colors.black,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displayLarge),
        displayMedium: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displayMedium),
        displaySmall: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displaySmall),
        headlineMedium: GoogleFonts.outfit(textStyle: baseTheme.textTheme.headlineMedium),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        color: const Color(0xFF141414),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}
