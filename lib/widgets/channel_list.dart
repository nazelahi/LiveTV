import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models/channel.dart';
import 'favorite_button.dart';
import 'skeleton.dart';
import 'states.dart';

class ChannelList extends StatelessWidget {
  const ChannelList({
    super.key,
    required this.channels,
    required this.favorites,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
    required this.onFavorite,
    this.selectedIds = const <String>{},
    this.selectionMode = false,
    this.emptyTitle = 'No channels found',
    this.emptyMessage = 'Try a different search term or pick another category.',
  });

  final List<Channel> channels;
  final Set<String> favorites;
  final Future<void> Function() onRefresh;
  final void Function(List<Channel> queue, int index) onTap;
  final void Function(Channel channel) onLongPress;
  final void Function(Channel channel) onFavorite;
  final Set<String> selectedIds;
  final bool selectionMode;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.accent,
        backgroundColor: AppTheme.background,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: emptyTitle,
                message: emptyMessage,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accent,
      backgroundColor: AppTheme.background,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 80),
        itemCount: channels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isFavorite = favorites.contains(channel.id);
          return _ChannelTile(
            channel: channel,
            isFavorite: isFavorite,
            selected: selectedIds.contains(channel.id),
            selectionMode: selectionMode,
            onTap: () => onTap(channels, index),
            onLongPress: () => onLongPress(channel),
            onFavorite: () => onFavorite(channel),
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.isFavorite,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavorite,
  });

  final Channel channel;
  final bool isFavorite;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${channel.name}, ${channel.group}',
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.textSecondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: selectionMode
                ? Border.all(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent
                        : Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 1.2),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              _TileLogo(channel: channel),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (!selectionMode) ...[
                FavoriteButton(isFavorite: isFavorite, onPressed: onFavorite),
                const SizedBox(width: 2),
              ],
              Icon(
                Icons.play_circle_outline_rounded,
                size: 20,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _TileLogo extends StatelessWidget {
  const _TileLogo({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 40,
        height: 40,
        color: Colors.white.withValues(alpha: 0.06),
        child: channel.hasLogo
            ? CachedNetworkImage(
                imageUrl: channel.logo!,
                fit: BoxFit.cover,
                memCacheWidth: kIsWeb ? null : 80,
                useOldImageOnUrlChange: true,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, url) => const ShimmerBox(),
                errorWidget: (context, url, error) => _fallback(channel),
              )
            : _fallback(channel),
      ),
    );
  }

  Widget _fallback(Channel channel) {
    final initial = channel.name.trim().isEmpty
        ? '?'
        : channel.name.trim().substring(0, 1).toUpperCase();
    return Container(
      color: AppTheme.textSecondary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}
