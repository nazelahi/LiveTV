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

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 96,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.78,
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
