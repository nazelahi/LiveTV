import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../data/models/channel.dart';
import '../providers/playlist_providers.dart';
import '../widgets/channel_grid.dart';
import '../widgets/channel_list.dart';
import '../widgets/states.dart';
import '../providers/player_provider.dart';
import 'watch_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(playlistProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Refresh failed. Showing the saved playlist.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openChannel(List<Channel> queue, int index) {
    if (queue.isEmpty) return;
    if (isWatchScreenOpen) {
      ref.read(playerProvider.notifier).play(queue[index], queue, index);
      return;
    }
    ref.read(playerProvider.notifier).play(queue[index], queue, index);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'watch'),
        builder: (_) => WatchScreen(queue: queue, initialIndex: index),
      ),
    );
  }

  void _toggleFavorite(Channel channel) {
    ref.read(favoritesProvider.notifier).toggle(channel.id);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(playlistProvider);
    final favorites = ref.watch(favoritesProvider);
    final showAdult = ref.watch(settingsProvider).showAdult;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favourites',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Your saved channels',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: ref.watch(settingsProvider).listView ? 'Grid view' : 'List view',
                    iconSize: 20,
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .setListView(!ref.read(settingsProvider).listView),
                    icon: Icon(
                      ref.watch(settingsProvider).listView
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Refresh playlist',
                      iconSize: 20,
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
                    ),
                ],
              ),
            ),
            Expanded(
              child: playlist.when(
                loading: () => const LoadingState(),
                error: (error, stackTrace) => ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(playlistProvider),
                ),
                data: (data) {
                  var channels = data.channels
                      .where(
                        (channel) =>
                            favorites.contains(channel.id) &&
                            (showAdult || channel.group != AppConfig.adultGroup),
                      )
                      .toList(growable: false);
                  final listView = ref.watch(settingsProvider).listView;

                  if (listView) {
                    return ChannelList(
                      channels: channels,
                      favorites: favorites,
                      onRefresh: _refresh,
                      onTap: _openChannel,
                      onLongPress: (_) {},
                      onFavorite: _toggleFavorite,
                      emptyTitle: 'No favourites yet',
                      emptyMessage:
                          'Tap the heart on any channel to keep it here for quick access.',
                    );
                  }

                  return ChannelGrid(
                    channels: channels,
                    favorites: favorites,
                    onRefresh: _refresh,
                    onTap: _openChannel,
                    onLongPress: (_) {},
                    onFavorite: _toggleFavorite,
                    emptyTitle: 'No favourites yet',
                    emptyMessage:
                        'Tap the heart on any channel to keep it here for quick access.',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
