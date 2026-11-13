import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF050506);
  static const Color backgroundAlt = Color(0xFF141416);
  static const Color surface = Color(0x1AFFFFFF);
  static const Color surfaceHigh = Color(0x26FFFFFF);

  /// Bright red used for icons, links, selection and accent text on dark.
  static const Color accent = Color(0xFFF5101F);

  /// Darker red used behind white labels on filled surfaces.
  static const Color accentFill = Color(0xFFC62828);

  static const Color accentSecondary = Color(0xFFE5484D);
  static const Color danger = Color(0xFFFF9100);

  /// Label color placed on bright accent fills (buttons, badges).
  static const Color onAccent = Color(0xFF200003);

  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFFB3B3B6);
  static const Color textMuted = Color(0xFF8A8A8F);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF000000),
      Color(0xFF120608),
      Color(0xFF1A090C),
      Color(0xFF0A0A0B),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5101F), Color(0xFF8E1118)],
  );

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: const Color(0xFF7A0E14),
      onPrimaryContainer: const Color(0xFFFFD9D9),
      secondary: accentSecondary,
      onSecondary: const Color(0xFF2B0507),
      secondaryContainer: const Color(0xFF3A0A0D),
      onSecondaryContainer: const Color(0xFFFFD9D9),
      error: danger,
      onError: const Color(0xFF2A1500),
      errorContainer: const Color(0xFF4A2800),
      onErrorContainer: const Color(0xFFFFE0B8),
      surface: backgroundAlt,
      onSurface: textPrimary,
      surfaceContainerHighest: backgroundAlt,
      outline: const Color(0xFF5C5C63),
      outlineVariant: const Color(0xFF2A2A2E),
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
        fillColor: surface,
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
        backgroundColor: surface,
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
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: textMuted.withValues(alpha: 0.3)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13,
          color: textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: backgroundAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: textMuted.withValues(alpha: 0.3)),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 13),
      ),
    );
  }
}
