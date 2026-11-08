import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF002B36);
  static const Color backgroundAlt = Color(0xFF073642);
  static const Color surface = Color(0x1A93A1A1);
  static const Color surfaceHigh = Color(0x2693A1A1);
  static const Color accent = Color(0xFF268BD2);
  static const Color accentSecondary = Color(0xFF2AA198);
  static const Color danger = Color(0xFFDC322F);

  static const Color textPrimary = Color(0xFF93A1A1);
  static const Color textSecondary = Color(0xFF839496);
  static const Color textMuted = Color(0xFF657B83);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF002B36),
      Color(0xFF073642),
      Color(0xFF0A4A5C),
      Color(0xFF073642),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF268BD2), Color(0xFF2AA198)],
  );

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0x1A93A1A1),
      primary: accent,
      secondary: accentSecondary,
      error: danger,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0x14FFFFFF),
        indicatorColor: accent.withValues(alpha: 0.25),
        elevation: 0,
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x1A93A1A1),
        hintStyle: TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x1A93A1A1),
        selectedColor: accent.withValues(alpha: 0.22),
        side: BorderSide(color: textMuted.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: TextStyle(fontSize: 12, color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: backgroundAlt,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: textMuted.withValues(alpha: 0.4)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
