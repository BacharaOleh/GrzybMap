import 'package:flutter/material.dart';

class AppColors {
  static const Color canvas = Color(0xFF060B08);
  static const Color surface = Color(0xFF0E1811);
  static const Color surfaceElevated = Color(0xFF142419);
  static const Color card = Color(0xFF182B1E);
  static const Color border = Color(0x2E34D399); // 18% emerald
  static const Color borderLight = Color(0x14FFFFFF);

  static const Color emeraldNeon = Color(0xFF34D399);
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color goldAmber = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);
  static const Color skyBlue = Color(0xFF38BDF8);

  static const Color textMain = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
}

class AppTheme {
  static ThemeData get forestDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emeraldNeon,
        secondary: AppColors.goldAmber,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: AppColors.canvas,
        onSurface: AppColors.textMain,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
