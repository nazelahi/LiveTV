import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 14,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;

  /// Sigma for the backdrop blur. Set to 0 to skip blur (cheaper).
  final double blur;

  /// Fill colour. Defaults to a translucent white tint.
  final Color? color;

  final BorderRadius borderRadius;
  final Border? border;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppTheme.textSecondary.withValues(alpha: 0.08);
    final outline = border; // null = no border by default

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: outline,
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (margin != EdgeInsets.zero) {
      content = Padding(padding: margin, child: content);
    }

    return content;
  }
}
