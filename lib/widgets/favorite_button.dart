import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 18,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
      onPressed: onPressed,
      iconSize: size,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFavorite ? AppTheme.accent : Colors.white70,
      ),
    );
  }
}
