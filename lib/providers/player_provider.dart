import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/constants.dart';
import '../core/playback_tuning.dart';
import '../core/stream_health.dart';
import '../core/stream_source.dart';

export '../core/playback_errors.dart';
import '../data/models/channel.dart';
import 'playlist_providers.dart';

/// Immutable snapshot of the running player.
class PlayerSession {
  const PlayerSession({
    required this.player,
    required this.controller,
    required this.channel,
    required this.queue,
    required this.index,
    this.playing = false,
    this.buffering = true,
    this.controlsVisible = true,
    this.muted = false,
    this.volume = 100,
    this.error,
    this.autoSkipRemaining,
    this.failedIds = const {},
    this.fullscreen = false,
  });

  final Player player;
  final VideoController controller;

  final Channel channel;
  final List<Channel> queue;
  final int index;

  final bool playing;
  final bool buffering;
  final bool controlsVisible;
  final bool muted;
  final double volume;
  final String? error;
  final int? autoSkipRemaining;
  final Set<String> failedIds;
  final bool fullscreen;

  Channel get currentChannel => channel;

  PlayerSession copyWith({
    Player? player,
    VideoController? controller,
    Channel? channel,
    List<Channel>? queue,
    int? index,
    bool? playing,
    bool? buffering,
    bool? controlsVisible,
    bool? muted,
    double? volume,
    String? error,
    bool clearError = false,
    int? autoSkipRemaining,
    bool clearAutoSkip = false,
    Set<String>? failedIds,
    bool? fullscreen,
  }) {
    return PlayerSession(
      player: player ?? this.player,
      controller: controller ?? this.controller,
      channel: channel ?? this.channel,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      controlsVisible: controlsVisible ?? this.controlsVisible,
      muted: muted ?? this.muted,
      volume: volume ?? this.volume,
      error: clearError ? null : (error ?? this.error),
      autoSkipRemaining:
          clearAutoSkip ? null : (autoSkipRemaining ?? this.autoSkipRemaining),
      failedIds: failedIds ?? this.failedIds,
      fullscreen: fullscreen ?? this.fullscreen,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerSession?> {
  PlayerNotifier(this.ref) : super(null);

  final Ref ref;

  StreamHealthMonitor? _health;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _hideTimer;
  Timer? _healthTimer;
  Timer? _autoSkipTimer;
  int _reconnectAttempts = 0;
  bool _isOpening = false;
  double _lastVolume = 100;

  /// Opens [channel] from [queue] at [index] in the shared player.
  Future<void> play(Channel channel, List<Channel> queue, int index) async {
    final clamped = index.clamp(0, queue.length - 1);

    if (state == null) {
      final settings = ref.read(settingsProvider);
      final tuning = playbackTuningFor(
        compatibilityMode: settings.compatibilityMode,
      );
      final player = Player(
        configuration: PlayerConfiguration(bufferSize: tuning.bufferSize),
      );
      final controller = VideoController(player);

      _health = StreamHealthMonitor(
        stallAfter: AppConfig.stallTimeout,
        bufferTimeout: AppConfig.bufferTimeout,
      );
      _reconnectAttempts = 0;

      _subscriptions.add(
        player.stream.playing.listen((playing) {
          if (state == null) return;
          _health?.onPlaying(playing, DateTime.now());
          if (playing) {
            _reconnectAttempts = 0;
            final failed = {...state!.failedIds}..remove(state!.channel.id);
            _cancelAutoSkip();
            state = state!.copyWith(
              playing: playing,
              error: null,
              clearError: true,
              failedIds: failed,
            );
          } else {
            state = state!.copyWith(playing: playing);
          }
          if (playing) _restartHideTimer();
        }),
      );
      _subscriptions.add(
        player.stream.buffering.listen((buffering) {
          if (state == null) return;
          _health?.onBuffering(buffering, DateTime.now());
          state = state!.copyWith(buffering: buffering);
        }),
      );
      _subscriptions.add(
        player.stream.position.listen((position) {
          _health?.onPosition(position, DateTime.now());
        }),
      );
      _subscriptions.add(
        player.stream.error.listen((message) {
          if (state == null) return;
          if (_isOpening) return;
          // Bypass transient tcp/ffurl errors: they are usually not dead
          // channels. Retry once, otherwise let the health monitor decide.
          if (isTransientStreamError(message)) {
            if (_reconnectAttempts < 1) {
              _reconnectAttempts++;
              unawaited(_reconnect());
            }
            return;
          }
          _failCurrent(_friendlyError(message));
        }),
      );

      _healthTimer = Timer.periodic(
        AppConfig.healthCheckInterval,
        (_) => _checkStreamHealth(),
      );

      await _applyPlaybackTuning(player, tuning);

      state = PlayerSession(
        player: player,
        controller: controller,
        channel: channel,
        queue: queue,
        index: clamped,
        buffering: ref.read(settingsProvider).autoplay,
        volume: 100,
        muted: false,
      );
    } else {
      _cancelAutoSkip();
      _reconnectAttempts = 0;
      state = state!.copyWith(
        channel: channel,
        queue: queue,
        index: clamped,
        playing: false,
        buffering: ref.read(settingsProvider).autoplay,
        error: null,
        clearError: true,
        autoSkipRemaining: null,
        clearAutoSkip: true,
      );
    }

    unawaited(_openCurrent());
  }

  Future<void> _applyPlaybackTuning(Player player, PlaybackTuning tuning) async {
    if (kIsWeb) return;
    if (tuning.properties.isEmpty) return;
    if (player.platform is! NativePlayer) return;
    final platform = player.platform;
    try {
      for (final entry in tuning.properties.entries) {
        await (platform as dynamic).setProperty(entry.key, entry.value);
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _openCurrent() async {
    final current = state;
    if (current == null) return;

    // On the web build (hosted over https), plain http:// streams are blocked
    // by the browser as mixed content. Detect this up front and surface a clear
    // message instead of letting the player hang on a blocked request.
    if (kIsWeb) {
      final src = parseStreamSource(current.channel.url);
      if (src.url.toLowerCase().startsWith('http://') &&
          Uri.base.scheme == 'https') {
        _failCurrent(
          'This stream uses http:// and cannot play inside the secure (https) '
          'website. Use "Open stream" to play it in an external '
          'player.',
        );
        return;
      }
    }

    _cancelAutoSkip();
    final autoplay = ref.read(settingsProvider).autoplay;
    _health?.reset();
    _health?.beginOpen(DateTime.now(), expectPlayback: autoplay);

    try {
      state = current.copyWith(
        error: null,
        clearError: true,
        buffering: autoplay,
        playing: false,
        controlsVisible: true,
        autoSkipRemaining: null,
        clearAutoSkip: true,
      );
    } catch (_) {}

    final source = parseStreamSource(current.channel.url);
    final headers = <String, String>{
      'User-Agent': 'VLC/3.0.20',
      if (source.headers != null) ...source.headers!,
    };
    final media = Media(
      source.url,
      httpHeaders: headers,
    );

    _isOpening = true;
    try {
      await current.player.open(media, play: autoplay);
      _restartHideTimer();
    } catch (error) {
      if (state == null) return;
      final raw = error.toString();
      // Bypass transient tcp/ffurl errors with a single retry.
      if (isTransientStreamError(raw) && _reconnectAttempts < 1) {
        _reconnectAttempts++;
        unawaited(_reconnect());
        return;
      }
      _failCurrent(_friendlyError(raw));
    } finally {
      _isOpening = false;
    }
  }

  void _checkStreamHealth() {
    final current = state;
    if (current == null || current.error != null) return;

    final action = _health?.check(DateTime.now());
    if (action == StreamHealth.reconnect) {
      _recoverFromStall();
    } else if (action == StreamHealth.timeout) {
      _failCurrent('The stream did not start in time.');
    }
  }

  void _recoverFromStall() {
    if (_reconnectAttempts >= 1) {
      _failCurrent('Playback stalled.');
      return;
    }
    _reconnectAttempts++;
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(buffering: true, error: null, clearError: true);

    try {
      await current.player.stop();
      if (state == null) return;
      await _openCurrent();
    } catch (error) {
      if (state == null) return;
      _failCurrent(error.toString());
    }
  }

  void _failCurrent(String message) {
    final current = state;
    if (current == null) return;

    final failed = {...current.failedIds, current.channel.id};
    try {
      if (current.error != message) {
        state = current.copyWith(
          error: message,
          buffering: false,
          controlsVisible: true,
          failedIds: failed,
        );
      } else {
        state = current.copyWith(failedIds: failed);
      }
    } catch (_) {
      // A watching widget may have been disposed; the state was still updated.
    }
    _hideTimer?.cancel();
    // Auto-skip is intentionally disabled: the BDIX streams frequently
    // report transient tcp/ffurl errors that are not actually dead channels.
  }

  String _friendlyError(String raw) => friendlyPlaybackError(raw);

  void _cancelAutoSkip() {
    _autoSkipTimer?.cancel();
    _autoSkipTimer = null;
    if (state?.autoSkipRemaining != null) {
      state = state?.copyWith(autoSkipRemaining: null, clearAutoSkip: true);
    }
  }

  void cancelAutoSkip() => _cancelAutoSkip();

  void _restartHideTimer() {
    _hideTimer?.cancel();
    final current = state;
    if (current == null || !current.playing) return;
    _hideTimer = Timer(AppConfig.playerControlsHideAfter, () {
      if (state != null && state!.playing && state!.error == null) {
        state = state!.copyWith(controlsVisible: false);
      }
    });
  }

  void zap(int delta) {
    final current = state;
    if (current == null || current.queue.length < 2) return;
    final next =
        (current.index + delta + current.queue.length) % current.queue.length;
    zapTo(next);
  }

  void zapTo(int index) {
    final current = state;
    if (current == null) return;

    _cancelAutoSkip();
    _reconnectAttempts = 0;
    final queue = current.queue;
    final channel =
        (index >= 0 && index < queue.length) ? queue[index] : current.channel;
    state = current.copyWith(channel: channel, index: index, playing: false);
    unawaited(_openCurrent());
  }

  Future<void> retry() async {
    _cancelAutoSkip();
    _reconnectAttempts = 0;
    final current = state;
    if (current == null) return;
    try {
      await current.player.stop();
    } catch (_) {
      // Ignore.
    }
    if (state == null) return;
    await _openCurrent();
  }

  Future<void> togglePlay() async {
    final current = state;
    if (current == null) return;
    if (!current.playing) {
      _health?.expectPlayback(DateTime.now());
    }
    await current.player.playOrPause();
  }

  Future<void> setVolume(double volume) async {
    final current = state;
    if (current == null) return;
    final clamped = volume.clamp(0.0, 100.0);
    if (clamped > 0) _lastVolume = clamped;
    await current.player.setVolume(clamped);
    state = current.copyWith(
      volume: clamped,
      muted: clamped == 0,
    );
  }

  Future<void> toggleMute() async {
    final current = state;
    if (current == null) return;
    if (current.muted) {
      await setVolume(_lastVolume > 0 ? _lastVolume : 100);
    } else {
      _lastVolume = current.volume > 0 ? current.volume : 100;
      await setVolume(0);
    }
  }

  void toggleControls() {
    final current = state;
    if (current == null || current.error != null) return;
    if (current.controlsVisible) {
      _hideTimer?.cancel();
      state = current.copyWith(controlsVisible: false);
    } else {
      _showControls();
    }
  }

  void _showControls() {
    final current = state;
    if (current == null) return;
    _hideTimer?.cancel();
    if (!current.controlsVisible) {
      state = current.copyWith(controlsVisible: true);
    }
    _restartHideTimer();
  }

  void showControls() => _showControls();

  void setFullscreen(bool value) {
    if (state == null) return;
    state = state!.copyWith(fullscreen: value);
  }

  /// Closes the player and releases its resources.
  Future<void> close() async {
    _hideTimer?.cancel();
    _healthTimer?.cancel();
    _autoSkipTimer?.cancel();
    _healthTimer = null;
    _autoSkipTimer = null;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    final player = state?.player;
    state = null;
    _health = null;
    _reconnectAttempts = 0;

    if (player == null) return;

    try {
      await player.stop();
    } catch (_) {
      // Ignore.
    }
    try {
      await player.dispose();
    } catch (_) {
      // Ignore.
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _healthTimer?.cancel();
    _autoSkipTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    final player = state?.player;
    state = null;
    if (player != null) {
      unawaited(player.stop().then((_) => player.dispose()));
    }
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerSession?>(
  (ref) => PlayerNotifier(ref),
);
