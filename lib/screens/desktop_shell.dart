import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import '../core/app_theme.dart';
import '../core/channel_filter.dart';
import '../core/constants.dart';
import '../core/open_url.dart';
import '../data/models/channel.dart';

import '../providers/channel_probe_provider.dart';
import '../providers/epg_providers.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_providers.dart';
import '../widgets/android_download_banner.dart';
import '../widgets/channel_grid.dart';
import '../widgets/quality_button.dart';
import '../widgets/channel_list.dart';
import '../widgets/featured_rail.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import 'featured_screen.dart';
import 'settings_screen.dart';

/// Desktop (wide-screen) shell: three side-by-side panels.
/// Sidebar | Channels | Player + info.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _query = '';
  String _group = 'All';
  bool _refreshing = false;
  List<Channel>? _lastProbedChannels;
  List<Channel>? _cachedFiltered;
  int _filterSignature = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfStale());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshIfStale() async {
    final state = ref.read(playlistProvider).valueOrNull;
    if (state == null) return;
    final updatedAt = state.updatedAt;
    if (updatedAt == null ||
        DateTime.now().difference(updatedAt) > AppConfig.staleAfter) {
      await _refresh(silent: true);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(playlistProvider.notifier).refresh();
      if (!silent && mounted) {
        final count = ref.read(playlistProvider).valueOrNull?.channels.length;
        _toast(count == null
            ? 'Playlist refreshed'
            : 'Playlist refreshed — $count channels');
      }
    } catch (_) {
      if (!silent && mounted) _toast('Refresh failed. Showing the saved playlist.');
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

  void _playChannel(List<Channel> queue, int index) {
    if (queue.isEmpty) return;
    ref.read(playerProvider.notifier).play(queue[index], queue, index);
  }

  void _toggleFavorite(Channel channel) {
    ref.read(favoritesProvider.notifier).toggle(channel.id);
  }

  bool _isEditing() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditing()) return KeyEventResult.ignored;

    final session = ref.read(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (session != null) notifier.togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (session != null && session.queue.length > 1) notifier.zap(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (session != null && session.queue.length > 1) notifier.zap(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        if (session != null) notifier.toggleMute();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyR:
        if (session != null) notifier.retry();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        if (node.context != null) mkv.toggleFullscreen(node.context!);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (session != null) notifier.close();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(playlistProvider);
    final settings = ref.watch(settingsProvider);
    final favorites = ref.watch(favoritesProvider);
    final state = playlist.valueOrNull;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
            ),
          ),
          ShimmerScope(
            child: Row(
              children: [
                // ---- Left sidebar ----
                Container(
                  width: AppConfig.desktopSidebarWidth,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.live_tv_rounded,
                                  size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('LiveTV',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary)),
                                  Text(
                                    state == null
                                        ? 'Loading…'
                                        : '${state.channels.length} channels',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh',
                              iconSize: 20,
                              onPressed: _refreshing ? null : () => _refresh(),
                              icon: _refreshing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.accent),
                                    )
                                  : const Icon(Icons.refresh_rounded,
                                      color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search channels',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: state == null
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                itemCount: ChannelFilter.visibleGroups(state.groups, settings.showAdult)
                                        .length +
                                    1,
                                itemBuilder: (context, index) {
                                  final groups =
                                      ChannelFilter.visibleGroups(state.groups, settings.showAdult);
                                  if (index == 0) {
                                    return _SidebarTile(
                                      label: 'All',
                                      selected: ChannelFilter.effectiveGroup(_group, settings.showAdult) == 'All',
                                      onTap: () => setState(() => _group = 'All'),
                                    );
                                  }
                                  final g = groups[index - 1];
                                  return _SidebarTile(
                                    label: g,
                                    selected: ChannelFilter.effectiveGroup(_group, settings.showAdult) == g,
                                    onTap: () => setState(() => _group = g),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: settings.listView ? 'Grid view' : 'List view',
                              onPressed: () => ref
                                  .read(settingsProvider.notifier)
                                  .setListView(!settings.listView),
                              icon: Icon(
                                settings.listView
                                    ? Icons.grid_view_rounded
                                    : Icons.view_list_rounded,
                                size: 20,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: AppTheme.backgroundAlt,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                                  ),
                                  child: SizedBox(
                                    width: 480,
                                    height: 640,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: const SettingsScreen(),
                                    ),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.settings_rounded,
                                  size: 20, color: AppTheme.textPrimary),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: settings.showAdult
                                  ? 'Hide adult'
                                  : 'Show adult',
                              onPressed: () => ref
                                  .read(settingsProvider.notifier)
                                  .setShowAdult(!settings.showAdult),
                              icon: Icon(
                                settings.showAdult
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ---- Center channels ----
                Expanded(
                  child: Column(
                    children: [
                      const AndroidDownloadBanner(),
                      if (state != null &&
                          _query.trim().isEmpty) ...[
                        const SizedBox(height: 4),
                        FeaturedRail(
                          onSeeAll: (kind) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FeaturedScreen(initialKind: kind),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (state != null) ...[
                        const SizedBox(height: 6),
                        _CategoryBar(
                          groups: ChannelFilter.visibleGroups(state.groups, settings.showAdult),
                          selected: ChannelFilter.effectiveGroup(_group, settings.showAdult),
                          onSelected: (g) => setState(() => _group = g),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Expanded(
                        child: playlist.when(
                          loading: () => kIsWeb
                              ? const Center(child: CircularProgressIndicator())
                              : (settings.listView
                                  ? const ChannelListSkeleton()
                                  : const ChannelGridSkeleton()),
                          error: (error, _) => ErrorState(
                            message: error.toString(),
                            onRetry: () => ref.invalidate(playlistProvider),
                          ),
                          data: (data) {
                            if (_lastProbedChannels != data.channels) {
                              _lastProbedChannels = data.channels;
                              unawaited(ref
                                  .read(channelProbeControllerProvider)
                                  .run(data.channels));
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
                            if (settings.listView) {
                              return ChannelList(
                                channels: channels,
                                favorites: favorites,
                                onRefresh: () => _refresh(),
                                onTap: _playChannel,
                                onLongPress: (_) {},
                                onFavorite: _toggleFavorite,
                              );
                            }
                            return ChannelGrid(
                              channels: channels,
                              favorites: favorites,
                              onRefresh: () => _refresh(),
                              onTap: _playChannel,
                              onLongPress: (_) {},
                              onFavorite: _toggleFavorite,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // ---- Right player panel (only when a channel is playing) ----
                if (ref.watch(playerProvider) != null)
                  Container(
                    width: (MediaQuery.sizeOf(context).width *
                          AppConfig.desktopPlayerPanelFraction)
                      .clamp(AppConfig.desktopPlayerPanelMinWidth,
                          AppConfig.desktopPlayerPanelMaxWidth),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.textMuted.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: const _PlayerPanel(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? AppTheme.accent.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerPanel extends ConsumerWidget {
  const _PlayerPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playerProvider);
    final epg = ref.watch(epgProvider).valueOrNull;

    if (session == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline_rounded,
                size: 56, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Select a channel to play',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final channel = session.channel;
    String? nowTitle;
    String? nextTitle;
    if (epg != null) {
      final key = channel.tvgId ?? channel.id;
      final now = epg.now(key);
      final next = epg.next(key);
      nowTitle = now?.title;
      nextTitle = next?.title;
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(playerProvider.notifier).togglePlay(),
            onDoubleTap: () => ref.read(playerProvider.notifier).togglePlay(),
            child: Video(
              controller: session.controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
              wakelock: false,
              pauseUponEnteringBackgroundMode: false,
              resumeUponEnteringForegroundMode: false,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (channel.hasLogo)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 30,
                          child: CachedNetworkImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.cover,
                            memCacheWidth: 88,
                            imageRenderMethodForWeb: kIsWeb
                                ? ImageRenderMethodForWeb.HttpGet
                                : ImageRenderMethodForWeb.HtmlImage,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(channel.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                          Text(channel.group,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (session.error != null) ...[
                  const SizedBox(height: 8),
                  Text(session.error!,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 12)),
                ],
                if (nowTitle != null) ...[
                  const SizedBox(height: 10),
                  Text('Now: $nowTitle',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.accent)),
                ],
                if (nextTitle != null) ...[
                  const SizedBox(height: 4),
                  Text('Next: $nextTitle',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      tooltip: session.playing ? 'Pause' : 'Play',
                      onPressed: () =>
                          ref.read(playerProvider.notifier).togglePlay(),
                      icon: Icon(session.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: session.muted ? 'Unmute' : 'Mute',
                      onPressed: () =>
                          ref.read(playerProvider.notifier).toggleMute(),
                      icon: Icon(session.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded),
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: session.queue.length > 1
                          ? () => ref.read(playerProvider.notifier).zap(-1)
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: session.queue.length > 1
                          ? () => ref.read(playerProvider.notifier).zap(1)
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    IconButton(
                      tooltip: 'Reload',
                      onPressed: () =>
                          ref.read(playerProvider.notifier).retry(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    IconTheme(
                      data: const IconThemeData(color: AppTheme.textPrimary),
                      child: QualityButton(player: session.player),
                    ),
                    IconButton(
                      tooltip: 'Fullscreen',
                      onPressed: () => mkv.toggleFullscreen(context),
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                    IconButton(
                      tooltip: 'Close player',
                      onPressed: () =>
                          ref.read(playerProvider.notifier).close(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton(
                      tooltip: 'Copy channel link',
                      onPressed: () async {
                        await shareChannelLink(session.channel.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(content: Text('Channel link copied')),
                            );
                        }
                      },
                      icon: const Icon(Icons.link_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      session.muted || session.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    Expanded(
                      child: Slider(
                        value: session.volume,
                        min: 0,
                        max: 100,
                        onChanged: (v) =>
                            ref.read(playerProvider.notifier).setVolume(v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
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
              label: Text(group),
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
      ),
    );
  }
}
