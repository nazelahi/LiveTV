import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';

import '../widgets/glass.dart';
import '../widgets/quality_button.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_theme.dart';
import '../core/open_url.dart';
import '../core/constants.dart';
import '../data/models/channel.dart';
import '../providers/epg_providers.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_providers.dart';
import 'player_screen.dart';
import '../core/screen_orientation.dart';

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
    with SingleTickerProviderStateMixin {
  List<Channel> _related = const [];
  bool _volumeOpen = false;
  double _deviceVolume = 1.0;
  StreamSubscription<double>? _volumeSubscription;
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();

    lockPortrait();

    try {
      FlutterVolumeController.updateShowSystemUI(false);
    } catch (_) {}
    try {
      FlutterVolumeController.getVolume().then((value) {
        if (mounted && value != null) setState(() => _deviceVolume = value);
      }).catchError((_) {});
    } catch (_) {}
    try {
      _volumeSubscription = FlutterVolumeController.addListener((value) {
        if (mounted) setState(() => _deviceVolume = value);
      });
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.initialIndex.clamp(0, widget.queue.length - 1);
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

  Future<void> _close() async {
    await ref.read(playerProvider.notifier).close();
    if (mounted) Navigator.of(context).pop();
  }

  void _showErrorDialog(Channel channel, String message, bool hasNext) {
    final detail = message.length > AppConfig.maxErrorMessageLength
        ? '${message.substring(0, AppConfig.maxErrorMessageLength)}…'
        : message;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${channel.name} is not responding'),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(playerProvider.notifier).retry();
            },
            child: const Text('Retry'),
          ),
          if (hasNext)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(playerProvider.notifier).zap(1);
              },
              child: const Text('Next channel'),
            ),
          if (kIsWeb)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openUrlInNewTab(channel.url);
              },
              child: const Text('Open stream'),
            ),
          if (kIsWeb)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openUrlInNewTab('vlc://${channel.url}');
              },
              child: const Text('Open in VLC'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    _tabController.dispose();
    lockPortrait();
    super.dispose();
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
    });

    final channel = session?.channel;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
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
          if (session?.error != null)
            IconButton(
              tooltip: 'Stream error',
              onPressed: () => _showErrorDialog(
                channel!,
                session!.error!,
                (session.queue.length > 1),
              ),
              icon: const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
            ),
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
          : Column(
              children: [
                Builder(
                  builder: (context) {
                    final size = MediaQuery.sizeOf(context);
                    final availableHeight = size.height -
                        MediaQuery.paddingOf(context).top -
                        kToolbarHeight;
                    final playerHeight = (size.width * 9 / 16)
                        .clamp(0.0, availableHeight * 0.45);
                    return SizedBox(
                      height: playerHeight,
                      width: size.width,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Video(
                            controller: session.controller,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                            wakelock: false,
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => notifier.toggleControls(),
                            onDoubleTap: () => notifier.togglePlay(),
                          ),
                          if (session.buffering && session.error == null)
                            const Center(
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          if (session.error != null && session.autoSkipRemaining != null)
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
                          if (session.controlsVisible)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _WatchControls(
                                player: session.player,
                                playing: session.playing,
                                muted: _deviceVolume == 0,
                                onPlayPause: () => notifier.togglePlay(),
                                 onMute: () => FlutterVolumeController.toggleMute(),
                                onVolumeToggle: () =>
                                    setState(() => _volumeOpen = !_volumeOpen),
                                 volume: _deviceVolume * 100,
                                 onVolumeChanged: (v) =>
                                     FlutterVolumeController.setVolume(v / 100),
                                volumeOpen: _volumeOpen,
                                onFullscreen: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PlayerScreen(),
                                    ),
                                  );
                                  if (!mounted) return;
                                  await exitFullscreenUi();
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 40,
                                height: 28,
                                child: session.channel.hasLogo
                                    ? CachedNetworkImage(
                                        imageUrl: session.channel.logo!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 80,
                                        errorWidget: (_, _, _) =>
                                            _channelFallback(session.channel),
                                      )
                                    : _channelFallback(session.channel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.channel.name,
                                    style: const TextStyle(
                                      fontSize: 16,
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
                                ? const Center(
                                    child: Text('No related channels found.'),
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
            ),
    ),
    );
  }
}

class _WatchControls extends StatelessWidget {
  const _WatchControls({
    required this.player,
    required this.playing,
    required this.muted,
    required this.volume,
    required this.onPlayPause,
    required this.onMute,
    required this.onVolumeToggle,
    required this.onVolumeChanged,
    required this.volumeOpen,
    required this.onFullscreen,
  });

  final Player player;
  final bool playing;
  final bool muted;
  final double volume;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onVolumeToggle;
  final ValueChanged<double> onVolumeChanged;
  final bool volumeOpen;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
            onPressed: onPlayPause,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Volume',
                onPressed: onVolumeToggle,
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
              ),
              if (volumeOpen)
                Positioned(
                  bottom: 44,
                  left: 0,
                  child: GlassContainer(
                    blur: 12,
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RotatedBox(
                            quarterTurns: 3,
                            child: SizedBox(
                              width: 90,
                              child: Slider(
                                value: volume,
                                min: 0,
                                max: 100,
                                onChanged: onVolumeChanged,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          IconButton(
                            tooltip: muted ? 'Unmute' : 'Mute',
                            onPressed: onMute,
                            icon: Icon(
                              muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
            ],
          ),
          IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: QualityButton(player: player),
          ),
          IconButton(
            tooltip: 'Fullscreen',
            onPressed: onFullscreen,
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
          ),
          const Spacer(),
        ],
      ),
        ],
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('TV guide not downloaded. Download it in Settings.'),
        ),
      );
    }

    final key = channel.tvgId ?? channel.id;
    final programmes = data.programmesFor(key);
    if (programmes.isEmpty) {
      return const Center(child: Text('No programmes available'));
    }

    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: programmes.length,
      itemBuilder: (context, index) {
        final programme = programmes[index];
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
