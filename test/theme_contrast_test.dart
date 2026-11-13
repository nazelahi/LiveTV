import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/core/app_theme.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/widgets/featured_visuals.dart';

/// WCAG relative luminance for an sRGB color.
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final lighter = max(a, b);
  final darker = min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('text contrast on the page background', () {
    test('primary text is clearly readable', () {
      expect(
        contrast(AppTheme.textPrimary, AppTheme.background),
        greaterThanOrEqualTo(12),
      );
    });

    test('secondary text is readable', () {
      expect(
        contrast(AppTheme.textSecondary, AppTheme.background),
        greaterThanOrEqualTo(7),
      );
    });

    test('muted text clears AA', () {
      expect(
        contrast(AppTheme.textMuted, AppTheme.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('muted text clears AA on cards and dialogs', () {
      expect(
        contrast(AppTheme.textMuted, AppTheme.backgroundAlt),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('accent roles', () {
    test('accent icons and text clear AA on the page', () {
      expect(
        contrast(AppTheme.accent, AppTheme.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('secondary accent clears AA on the page', () {
      expect(
        contrast(AppTheme.accentSecondary, AppTheme.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('danger clears AA on the page', () {
      expect(
        contrast(AppTheme.danger, AppTheme.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('labels on filled buttons clear AA', () {
      expect(
        contrast(AppTheme.onAccent, AppTheme.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('white labels on deep fills clear AA', () {
      expect(
        contrast(Colors.white, AppTheme.accentFill),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  test('the app background is near-black', () {
    expect(_luminance(AppTheme.background), lessThan(0.02));
  });

  test('the accent is red', () {
    expect(AppTheme.accent.r, greaterThan(AppTheme.accent.g));
    expect(AppTheme.accent.r, greaterThan(AppTheme.accent.b));
  });

  test('the accent reads red, not orange', () {
    // Orange/vermilion has a high green component and green above blue.
    expect(AppTheme.accent.g, lessThan(AppTheme.accent.r * 0.2));
    expect(AppTheme.accent.b, greaterThanOrEqualTo(AppTheme.accent.g));
  });

  group('status and kind badges', () {
    test('labels are readable on every featured kind color', () {
      for (final kind in FeaturedKind.values) {
        expect(
          contrast(AppTheme.onAccent, featuredKindColor(kind)),
          greaterThanOrEqualTo(4.5),
          reason: 'badge label for $kind',
        );
      }
    });

    test('the LIVE label is readable on the danger fill', () {
      expect(
        contrast(AppTheme.onAccent, AppTheme.danger),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
