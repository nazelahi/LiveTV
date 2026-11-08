import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/channel_filter.dart';
import '../core/constants.dart';
import '../data/models/channel.dart';

import '../providers/channel_probe_provider.dart';
import '../providers/playlist_providers.dart';
import '../widgets/channel_grid.dart';
import '../widgets/channel_list.dart';
import '../widgets/featured_rail.dart';
import '../widgets/skeleton.dart';
import '../widgets/update_notice.dart';
import '../widgets/states.dart';
import 'featured_screen.dart';
import 'watch_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _query = '';
  String _group = 'All';
  bool _refreshing = false;
  List<Channel>? _lastProbedChannels;

  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  List<Channel> _visibleChannels = const <Channel>[];
  List<Channel>? _cachedFiltered;
  int _filterSignature = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOnLoad());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshOnLoad() async {
    final state = ref.read(playlistProvider).valueOrNull;
    // Only refresh when we started from a cached snapshot; a fresh download
    // already happened during build().
    if (state == null || !state.fromCache) return;
    await _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(playlistProvider.notifier).refresh();
      if (!silent && mounted) {
        final count = ref.read(playlistProvider).valueOrNull?.channels.length;
        _toast(
          count == null
              ? 'Playlist refreshed'
              : 'Playlist refreshed — $count channels',
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        _toast('Refresh failed. Showing the saved playlist.');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value);
    });
  }


  void _openChannel(List<Channel> queue, int index) {
    if (queue.isEmpty) return;
    if (_selectionMode) {
      _toggleSelection(queue[index]);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(queue: queue, initialIndex: index),
      ),
    );
  }

  void _toggleFavorite(Channel channel) {
    ref.read(favoritesProvider.notifier).toggle(channel.id);
  }

  void _enterSelection(Channel channel) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(channel.id);
    });
  }

  void _toggleSelection(Channel channel) {
    setState(() {
      if (!_selectedIds.remove(channel.id)) {
        _selectedIds.add(channel.id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_visibleChannels.map((channel) => channel.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _addSelectedToFavorites() {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList(growable: false);
    ref.read(favoritesProvider.notifier).addAll(ids);
    final count = ids.length;
    _clearSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 1 ? 'Added to favourites' : 'Added $count channels to favourites',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                ref.read(favoritesProvider.notifier).removeAll(ids),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(playlistProvider);
    final settings = ref.watch(settingsProvider);
    final favorites = ref.watch(favoritesProvider);
    final state = playlist.valueOrNull;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              channelCount: state?.channels.length,
              refreshing: _refreshing,
              listView: settings.listView,
              onRefresh: () => _refresh(),
              onToggleView: () => ref
                  .read(settingsProvider.notifier)
                  .setListView(!settings.listView),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(),
                color: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search channels or categories',
                            prefixIcon: const Icon(Icons.search_rounded, size: 21),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchDebounce?.cancel();
                                      _searchController.clear();
                                      setState(() => _query = '');
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (state != null &&
                        _query.trim().isEmpty &&
                        !_selectionMode &&
                        (kIsWeb ||
                            MediaQuery.of(context).orientation ==
                                Orientation.portrait ||
                            MediaQuery.of(context).size.width >= 600))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FeaturedRail(
                            onSeeAll: (kind) => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FeaturedScreen(initialKind: kind),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (state != null) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      SliverToBoxAdapter(
                        child: _CategoryBar(
                          groups: ChannelFilter.visibleGroups(
                            state.groups,
                            settings.showAdult,
                          ),
                          selected: ChannelFilter.effectiveGroup(
                            _group,
                            settings.showAdult,
                          ),
                          onSelected: (group) => setState(() => _group = group),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
                    ],
                    SliverToBoxAdapter(child: UpdateNotice()),
                    if (_selectionMode)
                      SliverToBoxAdapter(
                        child: _SelectionBar(
                          selectedCount: _selectedIds.length,
                          onSelectAll: _selectAllVisible,
                          onCancel: _clearSelection,
                          onAddToFavorites:
                              _selectedIds.isEmpty ? null : _addSelectedToFavorites,
                        ),
                      ),
                  ],
                  body: playlist.when(
                    loading: () => kIsWeb
                        ? const Center(child: CircularProgressIndicator())
                        : (settings.listView
                            ? const ChannelListSkeleton()
                            : const ChannelGridSkeleton()),
                    error: (error, stackTrace) => ErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(playlistProvider),
                    ),
                    data: (data) {
                      if (_lastProbedChannels != data.channels) {
                        _lastProbedChannels = data.channels;
                        unawaited(ref.read(channelProbeControllerProvider).run(data.channels));
                      }
                      final signature = Object.hash(
                        _query,
                        _group,
                        settings.showAdult,
                        identityHashCode(data.channels),
                      );
                      if (_cachedFiltered == null ||
                          _filterSignature != signature) {
                        _filterSignature = signature;
                        _cachedFiltered = ChannelFilter.filter(
                          data.channels,
                          query: _query,
                          group: _group,
                          showAdult: settings.showAdult,
                        );
                      }
                      final channels = _cachedFiltered!;
                      _visibleChannels = channels;
                      if (settings.listView) {
                        return ChannelList(
                          channels: channels,
                          favorites: favorites,
                          selectedIds: _selectedIds,
                          selectionMode: _selectionMode,
                          onRefresh: () => _refresh(),
                          onTap: _openChannel,
                          onLongPress: _enterSelection,
                          onFavorite: _toggleFavorite,
                        );
                      }
                      return ChannelGrid(
                        channels: channels,
                        favorites: favorites,
                        selectedIds: _selectedIds,
                        selectionMode: _selectionMode,
                        onRefresh: () => _refresh(),
                        onTap: _openChannel,
                        onLongPress: _enterSelection,
                        onFavorite: _toggleFavorite,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onCancel,
    required this.onAddToFavorites,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback? onAddToFavorites;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel selection',
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: const Text('Select all'),
          ),
          FilledButton.icon(
            onPressed: onAddToFavorites,
            icon: const Icon(Icons.favorite_rounded, size: 16),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.channelCount,
    required this.refreshing,
    required this.listView,
    required this.onRefresh,
    required this.onToggleView,
  });

  final int? channelCount;
  final bool refreshing;
  final bool listView;
  final VoidCallback onRefresh;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10 + MediaQuery.of(context).padding.top,
        10,
        10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundAlt,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.textMuted.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              size: 19,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.appName,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  channelCount == null
                      ? 'Loading channels'
                      : '$channelCount channels',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: listView ? 'Grid view' : 'List view',
            iconSize: 20,
            onPressed: onToggleView,
            icon: Icon(
              listView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          if (refreshing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh playlist',
              iconSize: 22,
              onPressed: onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n == 'all') return Icons.apps_rounded;
  if (n.contains('sport')) return Icons.sports_soccer_rounded;
  if (n.contains('news')) return Icons.article_rounded;
  if (n.contains('movie') || n.contains('cinema') || n.contains('film')) {
    return Icons.movie_rounded;
  }
  if (n.contains('music') || n.contains('radio')) return Icons.music_note_rounded;
  if (n.contains('kid') || n.contains('child') || n.contains('cartoon')) {
    return Icons.child_care_rounded;
  }
  if (n.contains('entertain')) return Icons.celebration_rounded;
  if (n.contains('document')) return Icons.menu_book_rounded;
  if (n.contains('educat')) return Icons.school_rounded;
  if (n.contains('lifestyle') || n.contains('life')) return Icons.favorite_rounded;
  if (n.contains('general') || n.contains('other')) return Icons.public_rounded;
  return Icons.category_rounded;
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<String> groups;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = ['All', ...groups];
    return SizedBox(
      height: 30,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final group = items[index];
            final isSelected = group == selected;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcon(group),
                    size: 13,
                    color: isSelected ? AppTheme.accent : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(group),
                ],
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(group),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.accent : Colors.white70,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : AppTheme.textMuted.withValues(alpha: 0.4),
              ),
              selectedColor: AppTheme.accent.withValues(alpha: 0.18),
            );
          },
        ),
    );
  }
}
