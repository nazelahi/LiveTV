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

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/open_url.dart';
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

/// How many [WatchScreen]s are currently on the navigation stack, so callers
/// can update the existing player instead of pushing a duplicate.
int _openWatchScreens = 0;

/// Whether a [WatchScreen] is currently on the navigation stack.
bool get isWatchScreenOpen => _openWatchScreens > 0;

/// Geometry of one card in the channel queue strip (width + separator gap).
const double _queueItemExtent = 132;

/// Widest the watch page content may stretch on desktop. Beyond this the
/// page is centered instead of running edge-to-edge across the browser.
const double _watchMaxWidth = 1280;

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
  bool _closing = false;
  // Captured in initState: `ref` is unusable inside dispose(), and closing
  // the player there is exactly what must keep working after disposal.
  PlayerNotifier? _playerNotifier;
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final ScrollController _queueController = ScrollController();

  /// Refreshes the LIVE badge and the on-air progress bar between programme
  /// boundaries without re-watching the whole EPG provider.
  Timer? _clockTicker;
  int _centerQueueRetries = 0;

  @override
  void initState() {
    super.initState();
    _openWatchScreens++;
    _playerNotifier = ref.read(playerProvider.notifier);

    lockPortrait();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.initialIndex.clamp(0, widget.queue.length - 1);
      try {
        // A no-op when the caller already started this channel.
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
      _centerQueue(index);
    });

    _clockTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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

  /// Scrolls the queue strip so the card at [index] sits in the middle,
  /// mirroring the "you are here" behaviour of modern live-TV guides.
  void _centerQueue(int index) {
    final controller = _queueController;
    if (!controller.hasClients) {
      // The strip is not attached yet (too short a queue on the first frame);
      // retry a bounded number of times instead of recursing forever.
      if (_centerQueueRetries >= 10) return;
      _centerQueueRetries++;
      scheduleMicrotask(() {
        if (mounted) _centerQueue(index);
      });
      return;
    }
    _centerQueueRetries = 0;
    final position = controller.position;
    final target =
        (index * _queueItemExtent + _queueItemExtent / 2 - position.viewportDimension / 2)
            .clamp(0.0, position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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
    if (_closing) return;
    _closing = true;
    await ref.read(playerProvider.notifier).close();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _openWatchScreens--;
    _clockTicker?.cancel();
    _tabController.dispose();
    _queueController.dispose();
    // Closing the watch view without an explicit "close" action (browser back,
    // route removal) must stop playback; otherwise audio keeps playing with no
    // visible player. The view stays on the stack across window resizes (the
    // desktop shell has no inline player), so this is only skipped while
    // another watch view is still open.
    if (!isWatchScreenOpen) {
      // close() is a no-op when no session is running, so no state guard is
      // needed (and none is possible: ref is already disposed here).
      final notifier = _playerNotifier;
      if (notifier != null) {
        unawaited(notifier.close());
      }
    }
    lockPortrait();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    // On desktop the page gets a centered max-width layout; on phones it
    // keeps the edge-to-edge layout.
    final wide =
        MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint;

    // Refresh related list whenever the channel changes; leave when the
    // player was closed from outside this screen (the desktop shell's Esc
    // shortcut) instead of showing a spinner forever.
    ref.listen(playerProvider, (previous, next) {
      if (previous != null && next == null && !_closing) {
        _closing = true;
        Navigator.of(context).pop();
        return;
      }
      if (next != null && (previous?.channel.id != next.channel.id)) {
        _refreshRelated();
        _centerQueue(next.index.clamp(0, next.queue.length - 1));
      }
      if (kIsWeb) {
        syncPlaybackUrl(next?.channel.id);
      }
    });

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
          if (ModalRoute.of(context)?.isCurrent != true) {
            return KeyEventResult.ignored;
          }
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
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              bottom: false,
              child: session == null
                  ? const Center(child: CircularProgressIndicator())
                  : _watchContent(
                      context,
                      session: session,
                      notifier: notifier,
                      wide: wide,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _watchContent(
    BuildContext context, {
    required PlayerSession session,
    required PlayerNotifier notifier,
    required bool wide,
  }) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          session: session,
          onFullscreen: _enterFullscreen,
          onClose: _close,
        ),
        _PlayerStage(
          session: session,
          onFullscreen: _enterFullscreen,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // In very short viewports (split-screen, freeform
              // windows) the fixed sections would overflow; drop
              // the optional ones so the layout still fits.
              final h = constraints.maxHeight;
              final tight = h < 300;
              final medium = !tight && h < 460;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChannelHeader(
                    channel: session.channel,
                    compact: tight || medium,
                  ),
                  _ActionRow(
                    channel: session.channel,
                    notifier: notifier,
                    onFullscreen: _enterFullscreen,
                    compact: tight,
                  ),
                  if (!tight) ...[
                    _QueueStrip(
                      session: session,
                      notifier: notifier,
                      controller: _queueController,
                    ),
                    _SectionTabs(controller: _tabController),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _RelatedList(
                            related: _related,
                            queue: widget.queue,
                            notifier: notifier,
                          ),
                          _EpgGuideTab(channel: session.channel),
                        ],
                      ),
                    ),
                  ] else
                    Expanded(
                      child: _RelatedList(
                        related: _related,
                        queue: widget.queue,
                        notifier: notifier,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (wide) {
      // Center the page instead of stretching edge-to-edge across a wide
      // browser window; the app gradient shows on the unused sides.
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _watchMaxWidth),
          child: content,
        ),
      );
    }
    return content;
  }
}

// ---------------------------------------------------------------------------
// Player stage: full-bleed 16:9 video under a solid full-width top bar
// ---------------------------------------------------------------------------

/// Full-width bar above the player: back, channel title and the
/// favourite / reload / fullscreen / close actions.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.session,
    required this.onFullscreen,
    required this.onClose,
  });

  final PlayerSession session;
  final Future<void> Function() onFullscreen;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final isFavorite =
        ref.watch(favoritesProvider).contains(session.channel.id);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.backgroundAlt.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              session.channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: isFavorite
                ? 'Remove from favourites'
                : 'Add to favourites',
            onPressed: () => ref
                .read(favoritesProvider.notifier)
                .toggle(session.channel.id),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? AppTheme.accent : AppTheme.textPrimary,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'Reload stream',
            onPressed: notifier.retry,
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Fullscreen',
            onPressed: () => onFullscreen(),
            icon: const Icon(Icons.fullscreen_rounded, size: 24),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({
    required this.session,
    required this.onFullscreen,
  });

  final PlayerSession session;
  final Future<void> Function() onFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);

    // Cap the 16:9 stage against the screen height: in landscape the width
    // alone would make the stage taller than the viewport and overflow the
    // column (e.g. while the fullscreen route is pushed on top).
    final size = MediaQuery.sizeOf(context);
    // Match the centered desktop layout: cap the aspect computation at the
    // same width the content is constrained to.
    final stageWidth = size.width.clamp(0.0, _watchMaxWidth);
    final stageHeight =
        (stageWidth * 9 / 16).clamp(0.0, size.height * 0.55);

    return SizedBox(
      height: stageHeight,
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
                  onPressed: () => onFullscreen(),
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
              primaryButtonBar: [
                IconButton(
                  tooltip: 'Previous channel',
                  onPressed: session.queue.length > 1
                      ? () => notifier.zap(-1)
                      : null,
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const MaterialDesktopPlayOrPauseButton(iconSize: 48),
                const Spacer(),
                IconButton(
                  tooltip: 'Next channel',
                  onPressed:
                      session.queue.length > 1 ? () => notifier.zap(1) : null,
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            fullscreen:
                kDefaultMaterialDesktopVideoControlsThemeDataFullscreen,
            child: MaterialVideoControlsTheme(
              normal: MaterialVideoControlsThemeData(
                displaySeekBar: false,
                volumeGesture: true,
                brightnessGesture: false,
                seekGesture: false,
                seekOnDoubleTap: false,
                visibleOnMount: false,
                controlsHoverDuration: const Duration(seconds: 3),
                controlsTransitionDuration: const Duration(milliseconds: 300),
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
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  MaterialPlayOrPauseButton(iconSize: 48),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Next channel',
                    onPressed:
                        session.queue.length > 1 ? () => notifier.zap(1) : null,
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
                bottomButtonBar: [
                  const PlayerMuteButton(),
                  SizedBox(width: 150, child: PlayerVolumeSlider()),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fullscreen',
                    onPressed: () => onFullscreen(),
                    icon: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
                onVolumeChanged: (v) => notifier.setVolume(v * 100),
                initialVolume: (session.volume / 100).clamp(0.0, 1.0),
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
            ),
          ),
          if (session.error != null)
            Positioned.fill(
              child: PlayerStatusOverlay(
                channelName: session.channel.name,
                error: session.error,
                onRetry: notifier.retry,
                onNext: session.queue.length > 1 ? () => notifier.zap(1) : null,
                onOpenStream: kIsWeb
                    ? () => openUrlInNewTab(session.channel.streamUrl)
                    : null,
                onOpenVlc: kIsWeb
                    ? () =>
                        openUrlInNewTab('vlc://${session.channel.streamUrl}')
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
                  onPressed: () =>
                      ref.read(playerProvider.notifier).playFromUserGesture(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Tap to play'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel header: logo, live badge, meta chips and the on-air programme
// ---------------------------------------------------------------------------

class _ChannelHeader extends ConsumerWidget {
  const _ChannelHeader({required this.channel, this.compact = false});

  final Channel channel;

  /// Very short viewport: drop the chips and the on-air strip so the
  /// column still fits (split-screen / freeform windows).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epg = ref.watch(epgProvider).valueOrNull;
    final key = channel.tvgId ?? channel.id;
    final now = epg?.now(key);
    final next = epg?.next(key);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 44 : 56,
            height: compact ? 44 : 56,
            decoration: BoxDecoration(
              color: AppTheme.backgroundAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: channel.hasLogo
                ? CachedNetworkImage(
                    imageUrl: channel.logo!,
                    fit: BoxFit.contain,
                    memCacheWidth: 112,
                    imageRenderMethodForWeb: ImageRenderMethodForWeb.HtmlImage,
                    errorWidget: (_, _, _) => _channelFallback(channel),
                  )
                : _channelFallback(channel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                if (now != null) _LiveBadge(),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 5),
                  Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      label: channel.group,
                      highlight: true,
                    ),
                    if ((channel.country ?? '').trim().isNotEmpty)
                      _MetaChip(label: channel.country!.trim()),
                    if ((channel.language ?? '').trim().isNotEmpty)
                      _MetaChip(label: channel.language!.trim()),
                  ],
                ),
                if (now != null || next != null) ...[
                  const SizedBox(height: 8),
                  _OnAirRow(programme: now, next: next),
                ],
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Red dot + LIVE label used on the header and the guide rows.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded meta chip (group, country, language).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppTheme.accent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: highlight ? AppTheme.accent : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

/// "Now/Next" strip with a progress bar through the current programme.
class _OnAirRow extends StatelessWidget {
  const _OnAirRow({required this.programme, required this.next});

  final Programme? programme;
  final Programme? next;

  @override
  Widget build(BuildContext context) {
    final now = programme;
    final progress = now == null || !now.stop.isAfter(now.start)
        ? null
        : DateTime.now().difference(now.start).inMilliseconds /
            now.duration.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (now != null) ...[
          Row(
            children: [
              const _OnAirTag(label: 'NOW'),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_fmt(now.start)}–${_fmt(now.stop)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress?.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const _OnAirTag(label: 'NEXT'),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  next!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                _fmt(next!.start),
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _fmt(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _OnAirTag extends StatelessWidget {
  const _OnAirTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: label == 'NOW' ? AppTheme.accent : AppTheme.textMuted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action row: Save / Share / Reload / Fullscreen pills
// ---------------------------------------------------------------------------

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.channel,
    required this.notifier,
    required this.onFullscreen,
    this.compact = false,
  });

  final Channel channel;
  final PlayerNotifier notifier;
  final Future<void> Function() onFullscreen;

  /// Icon-only pills for very short viewports.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(channel.id);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, compact ? 6 : 10, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: _ActionPill(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: isFavorite ? 'Saved' : 'Save',
              active: isFavorite,
              compact: compact,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggle(channel.id),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionPill(
              icon: Icons.share_rounded,
              label: 'Share',
              compact: compact,
              onTap: () async {
                await shareChannelLink(channel.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionPill(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              compact: compact,
              onTap: notifier.retry,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionPill(
              icon: Icons.fullscreen_rounded,
              label: 'Expand',
              compact: compact,
              onTap: () => onFullscreen(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded action pill shared by the four actions.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppTheme.accent : AppTheme.textPrimary;
    return Material(
      color: active
          ? AppTheme.accent.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: compact ? 36 : 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue strip: horizontally scrolling channel cards centred on the current one
// ---------------------------------------------------------------------------

class _QueueStrip extends StatelessWidget {
  const _QueueStrip({
    required this.session,
    required this.notifier,
    required this.controller,
  });

  final PlayerSession session;
  final PlayerNotifier notifier;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (session.queue.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 86,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: session.queue.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ch = session.queue[index];
          final isCurrent = ch.id == session.channel.id;
          return _QueueCard(
            channel: ch,
            isCurrent: isCurrent,
            onTap: () => notifier.play(ch, session.queue, index),
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.channel,
    required this.isCurrent,
    required this.onTap,
  });

  final Channel channel;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _queueItemExtent - 8,
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? AppTheme.accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 32,
                  child: Center(
                    child: channel.hasLogo
                        ? CachedNetworkImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.contain,
                            memCacheWidth: 80,
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HtmlImage,
                            errorWidget: (_, _, _) => _channelFallback(channel),
                          )
                        : _channelFallback(channel),
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: isCurrent ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs + related list
// ---------------------------------------------------------------------------

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      dividerColor: Colors.white.withValues(alpha: 0.06),
      indicatorColor: AppTheme.accent,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 3,
      labelColor: AppTheme.accent,
      unselectedLabelColor: AppTheme.textSecondary,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.live_tv_rounded, size: 17),
              SizedBox(width: 6),
              Text('Related'),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 17),
              SizedBox(width: 6),
              Text('Guide'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedList extends StatelessWidget {
  const _RelatedList({
    required this.related,
    required this.queue,
    required this.notifier,
  });

  final List<Channel> related;
  final List<Channel> queue;
  final PlayerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (related.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_rounded, size: 32, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(
              'No related channels',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              'Try browsing another category.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: related.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final channel = related[index];
        return _RelatedCard(
          channel: channel,
          onTap: () {
            final i = queue.indexWhere((c) => c.id == channel.id);
            if (i >= 0) {
              notifier.play(channel, queue, i);
            } else {
              notifier.play(channel, [channel], 0);
            }
          },
        );
      },
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: channel.hasLogo
                    ? CachedNetworkImage(
                        imageUrl: channel.logo!,
                        fit: BoxFit.contain,
                        memCacheWidth: 104,
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HtmlImage,
                        errorWidget: (_, _, _) => _channelFallback(channel),
                      )
                    : _channelFallback(channel),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.play_circle_outline_rounded,
                size: 22,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guide tab
// ---------------------------------------------------------------------------

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
              Icon(
                Icons.calendar_month_rounded,
                size: 32,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                'TV guide not downloaded',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Download it in Settings to see programme times.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
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
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isLive
                ? AppTheme.accent.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: isLive
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(programme.start),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isLive ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _fmt(programme.stop),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            programme.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isLive) const _LiveBadge(),
                      ],
                    ),
                    if (programme.description != null &&
                        programme.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        programme.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
