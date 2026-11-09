import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/open_url.dart';
import '../core/screen_orientation.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_providers.dart';
import '../widgets/glass.dart';
import '../widgets/quality_button.dart';
import '../data/models/channel.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  bool _exiting = false;
  bool _pausedByLifecycle = false;

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    await exitFullscreenUi();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    enterFullscreenUi();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(playerProvider) == null) {
        _exit();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    exitFullscreenUi();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final session = ref.read(playerProvider);
    if (session == null || _exiting) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (session.playing) {
        _pausedByLifecycle = true;
        ref.read(playerProvider.notifier).togglePlay();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        final current = ref.read(playerProvider);
        if (current != null && !current.playing) {
          ref.read(playerProvider.notifier).togglePlay();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerProvider);
    if (session == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final channel = session.channel;
    final hasNext = session.queue.length > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: session.controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
            wakelock: false,
             pauseUponEnteringBackgroundMode: false,
             resumeUponEnteringForegroundMode: false,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(playerProvider.notifier).toggleControls(),
            onDoubleTap: () => ref.read(playerProvider.notifier).togglePlay(),
          ),
          if (session.buffering && session.error == null)
            const Center(
              child: SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.accent,
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: session.controlsVisible ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !session.controlsVisible,
              child: Container(
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: session.controlsVisible ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !session.controlsVisible,
              child: SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      channel: channel,
                      player: session.player,
                      isFavorite: ref
                          .watch(favoritesProvider)
                          .contains(channel.id),
                      onBack: () => _exit(),
                      onFavorite: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(channel.id),
                      onRetry: () => ref.read(playerProvider.notifier).retry(),
                      error: session.error,
                      onError: session.error == null
                          ? null
                          : () => _showErrorDialog(
                                channel,
                                session.error!,
                                session.queue.length > 1,
                              ),
                    ),
                    const Spacer(),
                    _BottomBar(
                      channel: channel,
                      playing: session.playing,
                      muted: session.muted,
                      hasNext: hasNext,
                      position: session.index + 1,
                      total: session.queue.length,
                      onPrevious: () =>
                          ref.read(playerProvider.notifier).zap(-1),
                      onNext: () => ref.read(playerProvider.notifier).zap(1),
                      onPlayPause: () =>
                          ref.read(playerProvider.notifier).togglePlay(),
                      onMute: () => ref.read(playerProvider.notifier).toggleMute(),
                      onRetry: () => ref.read(playerProvider.notifier).retry(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (session.error != null && session.autoSkipRemaining != null)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Skipping to the next working channel in ${session.autoSkipRemaining}s',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _showErrorDialog(Channel channel, String message, bool hasNext) {
    final detail = message.length > AppConfig.maxErrorMessageLength
        ? '${message.substring(0, AppConfig.maxErrorMessageLength)}…'
        : message;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.channel,
    required this.player,
    required this.isFavorite,
    required this.onBack,
    required this.onFavorite,
    required this.onRetry,
    this.error,
    this.onError,
  });

  final Channel channel;
  final Player player;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onRetry;
  final String? error;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 16,
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 32,
              height: 22,
              child: channel.hasLogo
                  ? CachedNetworkImage(
                      imageUrl: channel.logo!,
                      fit: BoxFit.cover,
                      memCacheWidth: 64,
                      imageRenderMethodForWeb: kIsWeb
                          ? ImageRenderMethodForWeb.HttpGet
                          : ImageRenderMethodForWeb.HtmlImage,
                      errorWidget: (_, _, _) => _playerFallback(channel),
                    )
                  : _playerFallback(channel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  channel.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            IconButton(
              tooltip: 'Stream error',
              onPressed: onError,
              icon: const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.danger,
              ),
            ),
          IconButton(
            tooltip: 'Reload stream',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
          QualityButton(player: player),
          IconButton(
            tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
            onPressed: onFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Copy stream URL',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: channel.url));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Stream URL copied')),
                  );
              }
            },
            icon: const Icon(Icons.link_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'retry') onRetry();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'retry',
                child: Text('Reload stream'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.channel,
    required this.playing,
    required this.muted,
    required this.hasNext,
    required this.position,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onMute,
    required this.onRetry,
  });

  final Channel channel;
  final bool playing;
  final bool muted;
  final bool hasNext;
  final int position;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 16,
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous channel',
            onPressed: hasNext ? onPrevious : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton.filled(
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: onPlayPause,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size(44, 44),
            ),
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
          IconButton(
            tooltip: 'Next channel',
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: muted ? 'Unmute' : 'Mute',
            onPressed: onMute,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LiveDot(),
                          SizedBox(width: 5),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasNext ? '$position of $total in this list' : channel.group,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppTheme.danger,
        shape: BoxShape.circle,
      ),
    );
  }
}


Widget _playerFallback(Channel channel) {
  final initial = channel.name.trim().isEmpty
      ? '?'
      : channel.name.trim().substring(0, 1).toUpperCase();
  return Container(
    color: AppTheme.textSecondary.withValues(alpha: 0.08),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.accent,
      ),
    ),
  );
}

