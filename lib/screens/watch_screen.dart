import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/player_status_overlay.dart';
import '../widgets/quality_button.dart';
import '../widgets/player_volume_controls.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_theme.dart';
import '../core/open_url.dart';
import '../core/constants.dart';
import '../data/models/channel.dart';
import '../data/models/epg.dart';
import '../providers/epg_providers.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_providers.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import '../core/screen_orientation.dart';
import '../core/fullscreen_web_stub.dart'
    if (dart.library.html) '../core/fullscreen_web.dart';
import '../core/sync_url_stub.dart'
    if (dart.library.html) '../core/sync_url_web.dart';

/// Tracks whether a [WatchScreen] is currently on the navigation stack, so
/// callers can update the existing player instead of pushing a duplicate.
bool isWatchScreenOpen = false;

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.queue,
    required this.initialIndex,
  });

  final List<Channel> queue;
  final int initialIndex;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Channel> _related = const [];
  bool _pausedByLifecycle = false;
  String? _initialChannelId;
  bool _handlingWideResize = false;
  bool? _openedWide;
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    isWatchScreenOpen = true;

    WidgetsBinding.instance.addObserver(this);
    lockPortrait();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.initialIndex.clamp(0, widget.queue.length - 1);
      _initialChannelId = widget.queue[index].id;
      try {
        ref.read(playerProvider.notifier).play(
              widget.queue[index],
              widget.queue,
              index,
            );
      } catch (e) {
        debugPrint('play failed: $e');
      }
      // Keep the in-app player at full volume; the on-screen slider drives
      // the device (hardware) volume instead.
      try {
        ref.read(playerProvider.notifier).setVolume(100);
      } catch (_) {}
      _refreshRelated();
    });
  }

  void _refreshRelated() {
    final session = ref.read(playerProvider);
    if (session == null) return;
    final current = session.channel;
    final related = widget.queue
        .where((c) => c.group == current.group && c.id != current.id)
        .take(30)
        .toList(growable: false);
    if (!mounted) return;
    setState(() => _related = related);
  }

  Future<void> _enterFullscreen() async {
    if (kIsWeb) {
      await enterBrowserFullscreen();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'player'),
          builder: (_) => const PlayerScreen(),
        ),
      );
      if (!mounted) return;
      await exitBrowserFullscreen();
      await exitFullscreenUi();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'player'),
        builder: (_) => const PlayerScreen(),
      ),
    );
    if (!mounted) return;
    await exitFullscreenUi();
  }

  Future<void> _close() async {
    await ref.read(playerProvider.notifier).close();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    isWatchScreenOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    // Closing the watch view without an explicit "close" action (browser back,
    // window resize, route removal) must stop playback; otherwise audio keeps
    // playing with no visible player on web.
    final session = ref.read(playerProvider);
    if (session != null &&
        (_initialChannelId == null ||
            session.channel.id == _initialChannelId)) {
      unawaited(ref.read(playerProvider.notifier).close());
    }
    lockPortrait();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only the route currently on top should react to app lifecycle changes;
    // otherwise a pushed fullscreen player and the underlying screen both pause
    // (and double-toggle) playback.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final session = ref.read(playerProvider);
    if (session == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (session.playing) {
        _pausedByLifecycle = true;
        ref.read(playerProvider.notifier).togglePlay();
      }
      if (!kIsWeb) {
        try {
          WakelockPlus.disable();
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        final current = ref.read(playerProvider);
        if (current != null && !current.playing) {
          ref.read(playerProvider.notifier).togglePlay();
        }
      }
      if (!kIsWeb) {
        try {
          WakelockPlus.enable();
        } catch (_) {}
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // On the web, a mobile player pushed onto the stack should hand off to the
    // desktop shell's inline player when the viewport grows wide enough, instead
    // of staying stuck in the mobile layout.
    if (!kIsWeb) return;
    final width = MediaQuery.sizeOf(context).width;
    if (_openedWide == null) {
      _openedWide = width >= AppConfig.desktopBreakpoint;
      return;
    }
    // Only auto-pop when the player was opened on a narrow viewport and later
    // resized to a wide one; a player intentionally opened on desktop stays.
    if (_openedWide == true) return;
    if (width < AppConfig.desktopBreakpoint || _handlingWideResize) return;
    _handlingWideResize = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _handlingWideResize = false;
        return;
      }
      if (MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint) {
        // Keep playback running: just pop the mobile view.
        Navigator.of(context).pop();
      }
      _handlingWideResize = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    // Refresh related list whenever the channel changes.
    ref.listen(playerProvider, (previous, next) {
      if (next != null && (previous?.channel.id != next.channel.id)) {
        _refreshRelated();
      }
      if (kIsWeb) {
        syncPlaybackUrl(next?.channel.id);
      }
    });

    final channel = session?.channel;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Focus(
        autofocus: kIsWeb,
        onKeyEvent: (node, event) {
          if (!kIsWeb || event is! KeyDownEvent) return KeyEventResult.ignored;
          if (ModalRoute.of(context)?.isCurrent != true) return KeyEventResult.ignored;
          final session = ref.read(playerProvider);
          if (session == null) return KeyEventResult.ignored;
          final notifier = ref.read(playerProvider.notifier);
          switch (event.logicalKey) {
            case LogicalKeyboardKey.space:
              notifier.togglePlay();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.keyM:
              notifier.toggleMute();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowLeft:
              if (session.queue.length > 1) notifier.zap(-1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowRight:
              if (session.queue.length > 1) notifier.zap(1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.keyF:
              _enterFullscreen();
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          channel?.name ?? 'Player',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (channel != null)
            IconButton(
              tooltip: 'Reload stream',
              onPressed: () => notifier.retry(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (channel != null)
            IconButton(
              tooltip: ref.watch(favoritesProvider).contains(channel.id)
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(channel.id),
              icon: Icon(
                ref.watch(favoritesProvider).contains(channel.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: AppTheme.accent,
              ),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MaterialDesktopVideoControlsTheme(
                        normal: MaterialDesktopVideoControlsThemeData(
                          displaySeekBar: false,
                          bottomButtonBar: [
                            const PlayerMuteButton(),
                            const SizedBox(width: 150, child: PlayerVolumeSlider()),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Fullscreen',
                              onPressed: _enterFullscreen,
                              icon: const Icon(Icons.fullscreen_rounded,
                                  color: Colors.white),
                            ),
                          ],
                          primaryButtonBar: [
                            IconButton(
                              tooltip: 'Previous channel',
                              onPressed: session.queue.length > 1
                                  ? () => notifier.zap(-1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: Colors.white),
                            ),
                            const Spacer(),
                            const MaterialDesktopPlayOrPauseButton(iconSize: 48),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Next channel',
                              onPressed: session.queue.length > 1
                                  ? () => notifier.zap(1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        fullscreen: kDefaultMaterialDesktopVideoControlsThemeDataFullscreen,
                        child: MaterialVideoControlsTheme(
                          normal: MaterialVideoControlsThemeData(
                          displaySeekBar: false,
                          volumeGesture: true,
                          brightnessGesture: false,
                          seekGesture: false,
                          seekOnDoubleTap: false,
                          visibleOnMount: false,
                          controlsHoverDuration: const Duration(seconds: 3),
                          controlsTransitionDuration:
                              const Duration(milliseconds: 300),
                          backdropColor: const Color(0x66000000),
                          topButtonBar: [
                            IconTheme(
                              data: const IconThemeData(color: Colors.white),
                              child: QualityButton(player: session.player),
                            ),
                          ],
                          primaryButtonBar: [
                            IconButton(
                              tooltip: 'Previous channel',
                              onPressed: session.queue.length > 1
                                  ? () => notifier.zap(-1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: Colors.white),
                            ),
                            const Spacer(),
                            MaterialPlayOrPauseButton(iconSize: 48),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Next channel',
                              onPressed: session.queue.length > 1
                                  ? () => notifier.zap(1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: Colors.white),
                            ),
                          ],
                          bottomButtonBar: [
                            const PlayerMuteButton(),
                            SizedBox(width: 150, child: PlayerVolumeSlider()),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Fullscreen',
                              onPressed: _enterFullscreen,
                              icon: const Icon(Icons.fullscreen_rounded,
                                  color: Colors.white),
                            ),
                          ],
                          onVolumeChanged: (v) => notifier.setVolume(v * 100),
                          initialVolume:
                              (session.volume / 100).clamp(0.0, 1.0),
                        ),
                        fullscreen: kDefaultMaterialVideoControlsThemeDataFullscreen,
                        child: Video(
                          controller: session.controller,
                          controls: AdaptiveVideoControls,
                          fit: BoxFit.contain,
                          wakelock: false,
                          pauseUponEnteringBackgroundMode: false,
                          resumeUponEnteringForegroundMode: false,
                        ),
                      ), // MaterialVideoControlsTheme
                      ), // MaterialDesktopVideoControlsTheme
                      if (session.error != null &&
                          session.autoSkipRemaining != null)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'Skipping in ${session.autoSkipRemaining}s',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      if (session.error != null)
                        Positioned.fill(
                          child: PlayerStatusOverlay(
                            channelName: session.channel.name,
                            error: session.error,
                            onRetry: notifier.retry,
                            onNext: session.queue.length > 1
                                ? () => notifier.zap(1)
                                : null,
                            onOpenStream: kIsWeb
                                ? () => openUrlInNewTab(session.channel.url)
                                : null,
                            onOpenVlc: kIsWeb
                                ? () => openUrlInNewTab('vlc://${session.channel.url}')
                                : null,
                          ),
                        )
                      else if (session.buffering &&
                          !session.playing &&
                          !session.needsUserGesture)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: PlayerStatusOverlay(
                              channelName: session.channel.name,
                            ),
                          ),
                        ),
                      if (session.needsUserGesture)
                        Positioned.fill(
                          child: Center(
                            child: FilledButton.icon(
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .playFromUserGesture(),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Tap to play'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: session.channel.hasLogo
                                    ? CachedNetworkImage(
                                        imageUrl: session.channel.logo!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 96,
                                        imageRenderMethodForWeb: kIsWeb
                                            ? ImageRenderMethodForWeb.HtmlImage
                                            : ImageRenderMethodForWeb.HtmlImage,
                                        errorWidget: (_, _, _) =>
                                            _channelFallback(session.channel),
                                      )
                                    : _channelFallback(session.channel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.channel.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${session.channel.group}  ·  ${session.channel.country ?? ''}  ${session.channel.language ?? ''}'
                                        .trim(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  _EpgNowNext(channel: session.channel),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(session.channel.id),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ref.watch(favoritesProvider).contains(session.channel.id)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(ref.watch(favoritesProvider).contains(session.channel.id)
                                      ? 'Saved'
                                      : 'Save'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await shareChannelLink(session.channel.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link copied')),
                                  );
                                }
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('Share'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => notifier.retry(),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('Reload'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (session.queue.length > 1)
                        SizedBox(
                          height: 76,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            itemCount: session.queue.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final ch = session.queue[index];
                              final isCurrent = ch.id == session.channel.id;
                              return InkWell(
                                onTap: () => notifier.play(ch, session.queue, index),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 120,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundAlt.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppTheme.accent
                                          : AppTheme.textMuted.withValues(alpha: 0.2),
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: ch.hasLogo
                                            ? CachedNetworkImage(
                                                imageUrl: ch.logo!,
                                                fit: BoxFit.contain,
                                                errorWidget: (_, _, _) =>
                                                    _channelFallback(ch),
                                              )
                                            : _channelFallback(ch),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ch.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? AppTheme.accent
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.live_tv_rounded, size: 18),
                                SizedBox(width: 6),
                                Text('Related'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 18),
                                SizedBox(width: 6),
                                Text('Guide'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Related
                            _related.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.live_tv_rounded,
                                            size: 32, color: AppTheme.textMuted),
                                        const SizedBox(height: 8),
                                        Text('No related channels',
                                            style: TextStyle(
                                                color: AppTheme.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text('Try browsing another category.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      16,
                                    ),
                                    itemCount: _related.length,
                                    itemBuilder: (context, index) {
                                      final channel = _related[index];
                                      return _RelatedTile(
                                        channel: channel,
                                        onTap: () {
                                          final i = widget.queue
                                              .indexWhere((c) => c.id == channel.id);
                                          if (i >= 0) {
                                            notifier.play(
                                              channel,
                                              widget.queue,
                                              i,
                                            );
                                          } else {
                                            notifier.play(channel, [channel], 0);
                                          }
                                        },
                                      );
                                    },
                                  ),
                            // Guide
                            _EpgGuideTab(channel: session.channel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                );
                // Single cinematic column at every width; the tabs' content scrolls internally.
                return content;
              },
            ),
          ),
          ),
        ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 44,
                    height: 28,
                    child: channel.hasLogo
                        ? CachedNetworkImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.cover,
                            memCacheWidth: 88,
                            imageRenderMethodForWeb: kIsWeb
                                ? ImageRenderMethodForWeb.HtmlImage
                                : ImageRenderMethodForWeb.HtmlImage,
                            errorWidget: (_, _, _) => _fallback(channel),
                          )
                        : _fallback(channel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                const Icon(Icons.play_circle_outline_rounded,
                    size: 20, color: AppTheme.textMuted),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
        ],
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _EpgNowNext extends ConsumerWidget {
  const _EpgNowNext({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(epgProvider).valueOrNull;
    if (data == null) return const SizedBox.shrink();

    final key = channel.tvgId ?? channel.id;
    final now = data.now(key);
    final next = data.next(key);
    if (now == null && next == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (now != null)
            Text(
              'Now: ${now.title}  (${_fmt(now.start)}–${_fmt(now.stop)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
          if (next != null)
            Text(
              'Next: ${next.title}  (${_fmt(next.start)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Widget _channelFallback(Channel channel) {
  final initial = channel.name.trim().isEmpty
      ? '?'
      : channel.name.trim().substring(0, 1).toUpperCase();
  return Container(
    color: AppTheme.textSecondary.withValues(alpha: 0.08),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.accent,
      ),
    ),
  );
}

class _EpgGuideTab extends ConsumerWidget {
  const _EpgGuideTab({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(epgProvider).valueOrNull;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 32, color: AppTheme.textMuted),
              const SizedBox(height: 8),
              Text('TV guide not downloaded',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text('Download it in Settings to see programme times.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  final wide = MediaQuery.sizeOf(context).width >= 900;
                  if (wide) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const SettingsScreen(),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  }
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    final key = channel.tvgId ?? channel.id;
    final programmes = data.programmesFor(key);
    if (programmes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No guide data for this channel.\n'
            'The published guide does not cover every channel.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final now = DateTime.now();
    // Start from what is airing now instead of the first entry of the day.
    // A stale guide (nothing upcoming) still shows its full list.
    final upcoming = upcomingProgrammes(programmes, now);
    final visible = upcoming.isEmpty ? programmes : upcoming;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final programme = visible[index];
        final isLive = !programme.start.isAfter(now) &&
            programme.stop.isAfter(now);
        return Container(
          color: isLive ? AppTheme.accent.withValues(alpha: 0.08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_fmt(programme.start)} – ${_fmt(programme.stop)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isLive ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                programme.title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (programme.description != null &&
                  programme.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  programme.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
