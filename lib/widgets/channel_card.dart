import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../data/models/channel.dart';
import 'favorite_button.dart';
import 'skeleton.dart';

class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.isFavorite = false,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
    this.onFavorite,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isFavorite;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${channel.name}, ${channel.group}',
      button: true,
      selected: selected,
      hint: selectionMode
          ? (selected ? 'Selected' : 'Double tap to select')
          : 'Double tap to play, long press to select',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: selectionMode
                ? Border.all(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selectionMode)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent
                          : Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.2),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 54,
                      child: _Logo(channel: channel),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onFavorite != null &&
                  !selectionMode &&
                  !(kIsWeb &&
                      MediaQuery.sizeOf(context).width >=
                          AppConfig.desktopBreakpoint))
                Positioned(
                  top: 2,
                  right: 2,
                  child: FavoriteButton(
                    isFavorite: isFavorite,
                    onPressed: onFavorite!,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    if (!channel.hasLogo) return _fallback();

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: Colors.white.withValues(alpha: 0.06),
          child: CachedNetworkImage(
            imageUrl: channel.logo!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            memCacheWidth: 220,
            imageRenderMethodForWeb: kIsWeb
                ? ImageRenderMethodForWeb.HttpGet
                : ImageRenderMethodForWeb.HtmlImage,
            useOldImageOnUrlChange: true,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (context, url) => const SizedBox.expand(
              child: ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(6))),
            ),
            errorWidget: (context, url, error) => _fallback(),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    final initial = channel.name.trim().isEmpty
        ? '?'
        : channel.name.trim().substring(0, 1).toUpperCase();

    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

