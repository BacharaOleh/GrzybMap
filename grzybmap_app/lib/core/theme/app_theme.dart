import 'package:flutter/material.dart';

class AppColors {
  static const Color canvas = Color(0xFF060B08);
  static const Color surface = Color(0xFF0E1811);
  static const Color surfaceElevated = Color(0xFF142419);
  static const Color card = Color(0xFF182B1E);
  static const Color border = Color(0x1AFFFFFF); // Neutral hairline 10% white
  static const Color borderLight = Color(0x0FFFFFFF); // Subtle internal divider 6% white
  static const Color borderActive = Color(0x6634D399); // Emerald accent glow for active/selected states

  static const Color emeraldNeon = Color(0xFF34D399);
  static const Color emeraldLight = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color goldAmber = Color(0xFFFBBF24);
  static const Color amberWarn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF87171);
  static const Color skyBlue = Color(0xFF38BDF8);

  static const Color textMain = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
}

class AppRadii {
  static const double sheet = 24.0;
  static const double card = 16.0;
  static const double inner = 10.0;
  static const double pill = 999.0;

  static const BorderRadius sheetRadius = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius innerRadius = BorderRadius.all(Radius.circular(inner));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

class AppTypography {
  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textMain,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textMain,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textMain,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelSmall = TextStyle(
    color: AppColors.textDim,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle microLabel = TextStyle(
    color: AppColors.textDim,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle numberTabular = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
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
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        space: 1,
        thickness: 1,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: AppColors.borderLight, width: 1.0),
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
