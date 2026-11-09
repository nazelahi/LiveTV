import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models/channel.dart';
import 'channel_card.dart';
import 'states.dart';

class ChannelGrid extends StatelessWidget {
  const ChannelGrid({
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
    this.emptyMessage =
        'Try a different search term or pick another category.',
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
        backgroundColor: AppTheme.surface,
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

    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    final isWebWide = kIsWeb && isWide;
    final maxExtent = isWebWide ? 340.0 : (isWide ? 150.0 : 96.0);
    final spacing = isWide ? 10.0 : 6.0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isWide ? 12 : 8,
          4,
          isWide ? 12 : 8,
          isWide ? 24 : 80,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: isWebWide ? 3.2 : (isWide ? 0.85 : 0.78),
        ),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return ChannelCard(
            channel: channel,
            isFavorite: favorites.contains(channel.id),
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
