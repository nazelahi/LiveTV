import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
    this.failedIds = const {},
    this.fullscreen = false,
    this.needsUserGesture = false,
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
  final Set<String> failedIds;
  final bool fullscreen;
  final bool needsUserGesture;

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
    Set<String>? failedIds,
    bool? fullscreen,
    bool? needsUserGesture,
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
      failedIds: failedIds ?? this.failedIds,
      fullscreen: fullscreen ?? this.fullscreen,
      needsUserGesture: needsUserGesture ?? this.needsUserGesture,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerSession?> {
  PlayerNotifier(this.ref) : super(null) {
    unawaited(_initAudioSession());
    unawaited(_initConnectivity());
    _initLifecycle();
  }

  final Ref ref;

  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<AudioInterruptionEvent>? _audioInterruptionSub;
  StreamSubscription<void>? _audioNoisySub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _pausedByAudioInterruption = false;

  StreamHealthMonitor? _health;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _hideTimer;
  Timer? _healthTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastReconnectAt;
  bool _isOpening = false;
  double _lastVolume = 100;

  /// Incremented for every open; lets a superseded open ignore its own result.
  int _openSeq = 0;

  /// Applied once per player before the first open; awaited by [_openCurrent].
  Future<void>? _tuningReady;

  /// True when the open in flight goes through the web stream proxy.
  bool _openViaProxy = false;

  bool _inBackground = false;
  bool _pausedByLifecycle = false;

  /// True while the user explicitly paused playback; a connectivity change
  /// must then not restart the stream (that would resume audio unexpectedly).
  bool _pausedByUser = false;

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _audioInterruptionSub = session.interruptionEventStream.listen((event) {
        final current = state;
        if (current == null) return;

        if (event.begin) {
          if (current.playing) {
            _pausedByAudioInterruption = true;
            try {
              current.player.pause();
            } catch (_) {}
          }
        } else {
          if (_pausedByAudioInterruption) {
            _pausedByAudioInterruption = false;
            // Resume only after a pause/duck interruption, not for
            // permanent focus loss (e.g. a phone call still active).
            if (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.duck) {
              try {
                current.player.play();
              } catch (_) {}
            }
          }
        }
      });

      _audioNoisySub = session.becomingNoisyEventStream.listen((_) {
        final current = state;
        if (current == null || !current.playing) return;
        _pausedByAudioInterruption = true;
        try {
          current.player.pause();
        } catch (_) {}
      });
    } catch (_) {
      // Best effort: audio focus is a nice-to-have.
    }
  }

  /// Watches the app lifecycle once, for every screen that shows the player.
  ///
  /// Only hidden/paused mean the player is no longer visible. `inactive` also
  /// fires on a web window blur, the iOS control centre or an unfocused
  /// split-screen window, where playback should continue.
  void _initLifecycle() {
    try {
      _lifecycleListener = AppLifecycleListener(
        onStateChange: (lifecycle) {
          if (lifecycle == AppLifecycleState.hidden ||
              lifecycle == AppLifecycleState.paused) {
            onAppBackgrounded();
          } else if (lifecycle == AppLifecycleState.resumed) {
            onAppForegrounded();
          }
        },
      );
    } catch (_) {
      // No widgets binding (pure unit tests): lifecycle handling is skipped.
    }
  }

  Future<void> _initConnectivity() async {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final current = state;
        if (current == null) return;
        if (results.contains(ConnectivityResult.none)) return;
        // Only act when playback has actually stalled or failed. A stream the
        // user paused, or one paused because the app went to the background,
        // must not be restarted (that would resume audio unexpectedly).
        if (_inBackground ||
            _pausedByUser ||
            current.needsUserGesture ||
            current.playing) {
          return;
        }
        if (!current.buffering && current.error == null) return;
        _reconnectAttempts = 0;
        _lastReconnectAt = null;
        unawaited(_reconnect());
      });
    } catch (_) {
      // Best effort.
    }
  }

  /// Opens [channel] from [queue] at [index] in the shared player.
  ///
  /// Asking again for the channel that is already opening or playing only
  /// updates the queue: list screens call this and then push a [WatchScreen],
  /// which asks for the same channel once it is on screen.
  Future<void> play(Channel channel, List<Channel> queue, int index) async {
    _setWakelock(true);
    final clamped = index.clamp(0, queue.length - 1);

    final existing = state;
    if (existing != null &&
        existing.channel.id == channel.id &&
        existing.error == null &&
        !existing.needsUserGesture &&
        (existing.playing || _isOpening)) {
      state = existing.copyWith(queue: queue, index: clamped);
      return;
    }

    _reconnectAttempts = 0;
    _lastReconnectAt = null;
    _pausedByUser = false;

    if (existing == null) {
      // Everything up to the first open happens synchronously, so a second
      // play() call can never see an empty state and create another player.
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
            _pausedByUser = false;
            final failed = {...state!.failedIds}..remove(state!.channel.id);
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
          // An autoplay block is not a dead stream: show the "tap to play"
          // prompt and wait for a user gesture. It can arrive while the
          // stream is still opening, so check it before the guard below.
          if (isAutoplayBlockedError(message)) {
            _promptUserGesture();
            return;
          }
          // The browser's "media removed from the document" race is not a dead
          // stream; ignore it and let the in-flight open() finish.
          if (isMediaRemovalError(message)) {
            return;
          }
          if (_isOpening) return;
          // Bypass transient tcp/ffurl errors: they are usually not dead
          // channels. Retry once, otherwise let the health monitor decide.
          if (isTransientStreamError(message)) {
            final now = DateTime.now();
            // Avoid rapid reopen loops: BDIX streams can emit these errors in
            // bursts. Reconnect at most once per cooldown window.
            // If playback is still active, let FFmpeg handle the hiccup internally
            // instead of tearing down and reopening the stream (which looks like a
            // reload to the user).
            if (state?.playing == true) {
              return;
            }
            if (_lastReconnectAt != null &&
                now.difference(_lastReconnectAt!) < const Duration(seconds: 15)) {
              return;
            }
            if (_reconnectAttempts < 1) {
              _reconnectAttempts++;
              _lastReconnectAt = now;
              unawaited(_reconnect());
            }
            return;
          }
          _failCurrent(_openFailureMessage(message));
        }),
      );

      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(
        AppConfig.healthCheckInterval,
        (_) => _checkStreamHealth(),
      );

      _tuningReady = _applyPlaybackTuning(player, tuning);

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
      state = state!.copyWith(
        channel: channel,
        queue: queue,
        index: clamped,
        playing: false,
        buffering: ref.read(settingsProvider).autoplay,
        error: null,
        clearError: true,
        needsUserGesture: false,
      );
    }

    await _openCurrent();
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
    final seq = ++_openSeq;

    // On the web build (hosted over https), plain http:// streams are blocked
    // by the browser as mixed content. When a public HTTPS proxy is configured
    // (AppConfig.webStreamProxyBase) we relay them through it; otherwise
    // surface a clear message instead of letting the player hang.
    if (kIsWeb) {
      final src = parseStreamSource(current.channel.url);
      if (src.url.toLowerCase().startsWith('http://') &&
          Uri.base.scheme == 'https' &&
          AppConfig.webStreamProxyBase.isEmpty) {
        _failCurrent(
          'This stream uses http:// and cannot play inside the secure (https) '
          'website. Use "Open stream" to play it in an external '
          'player.',
        );
        return;
      }
    }

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
        needsUserGesture: false,
      );
    } catch (_) {}

    final source = parseStreamSource(current.channel.url);
    final headers = <String, String>{
      'User-Agent': 'VLC/3.0.20',
      if (source.headers != null) ...source.headers!,
    };
    final target = proxiedStreamUrl(source.url);
    final media = Media(target, httpHeaders: headers);

    _openViaProxy = target != source.url;
    _isOpening = true;
    try {
      final tuning = _tuningReady;
      if (tuning != null) await tuning;
      // A newer open (channel switch, retry) or close() took over meanwhile.
      if (seq != _openSeq || state?.player != current.player) return;
      // media_kit's open() already stops the previous media internally.
      // Calling stop() separately on web resets the video element and races
      // with the new open(), which can prevent autoplay on channel switches.
      await current.player.open(media, play: autoplay);
      if (seq != _openSeq) return;
      if (_inBackground && autoplay) {
        // The app went to the background while the stream was opening.
        _pausedByLifecycle = true;
        unawaited(current.player.pause());
      }
      _restartHideTimer();
    } catch (error) {
      // Errors from a superseded open belong to a channel no longer shown.
      if (seq != _openSeq || state == null) return;
      final raw = error.toString();
      if (isAutoplayBlockedError(raw)) {
        _promptUserGesture();
        return;
      }
      if (isMediaRemovalError(raw)) {
        return;
      }
      // Bypass transient tcp/ffurl errors with a single retry.
      if (isTransientStreamError(raw) && _reconnectAttempts < 1) {
        _reconnectAttempts++;
        unawaited(_reconnect());
        return;
      }
      _failCurrent(_openFailureMessage(raw));
    } finally {
      if (seq == _openSeq) _isOpening = false;
    }
  }

  void _checkStreamHealth() {
    final current = state;
    if (current == null ||
        _inBackground ||
        current.error != null ||
        current.needsUserGesture) {
      return;
    }

    final action = _health?.check(DateTime.now());
    if (action == StreamHealth.reconnect) {
      _recoverFromStall();
    } else if (action == StreamHealth.timeout) {
      _failCurrent('The stream did not start in time.');
    }
  }

  void _recoverFromStall() {
    final now = DateTime.now();
    if (_lastReconnectAt != null &&
        now.difference(_lastReconnectAt!) < const Duration(seconds: 15)) {
      return;
    }
    if (_reconnectAttempts >= 1) {
      _failCurrent('Playback stalled.');
      return;
    }
    _reconnectAttempts++;
    _lastReconnectAt = now;
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(buffering: true, error: null, clearError: true);

    try {
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
          needsUserGesture: false,
        );
      } else {
        state = current.copyWith(
          failedIds: failed,
          needsUserGesture: false,
        );
      }
    } catch (_) {
      // A watching widget may have been disposed; the state was still updated.
    }
    _hideTimer?.cancel();
    // Auto-skip is intentionally disabled: the BDIX streams frequently
    // report transient tcp/ffurl errors that are not actually dead channels.
  }

  String _friendlyError(String raw) => friendlyPlaybackError(raw);

  /// Like [_friendlyError], but explains that the web relay is the likely
  /// culprit when the failing stream went through it (HLS playlists with
  /// relative or http:// segments cannot be relayed this way).
  String _openFailureMessage(String raw) {
    if (_openViaProxy) {
      return 'This http:// stream could not be relayed to the secure (https) '
          'website. Use "Open stream" to play it in an external player.';
    }
    return _friendlyError(raw);
  }

  void _setWakelock(bool enabled) {
    if (kIsWeb) return;
    unawaited(
      Future<void>(() => enabled ? WakelockPlus.enable() : WakelockPlus.disable())
          .catchError((_) {}),
    );
  }

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

  Future<void> zapTo(int index) async {
    final current = state;
    if (current == null) return;

    _reconnectAttempts = 0;
    final queue = current.queue;
    final channel =
        (index >= 0 && index < queue.length) ? queue[index] : current.channel;
    state = current.copyWith(channel: channel, index: index, playing: false);
    await _openCurrent();
  }

  Future<void> retry() async {
    _reconnectAttempts = 0;
    final current = state;
    if (current == null) return;
    // media_kit's open() stops the previous media internally.
    if (state == null) return;
    await _openCurrent();
  }

  Future<void> togglePlay() async {
    final current = state;
    if (current == null) return;
    // An explicit user choice wins over a pending lifecycle resume/pause.
    _pausedByLifecycle = false;
    // Remember an explicit pause so a connectivity change while the stream is
    // still buffering does not restart playback behind the user's back.
    _pausedByUser = current.playing;
    if (!current.playing) {
      _health?.expectPlayback(DateTime.now());
    }
    await current.player.playOrPause();
  }

  /// Shows the "tap to play" prompt after the browser blocked autoplay.
  void _promptUserGesture() {
    final current = state;
    if (current == null || current.needsUserGesture) return;
    try {
      state = current.copyWith(
        needsUserGesture: true,
        playing: false,
        buffering: false,
        error: null,
        clearError: true,
        controlsVisible: true,
      );
    } catch (_) {
      // A watching widget may have been disposed; the state was still updated.
    }
  }

  /// Clears the "tap to play" prompt and starts playback from a user gesture.
  Future<void> playFromUserGesture() async {
    final current = state;
    if (current == null) return;
    _pausedByUser = false;
    _health?.expectPlayback(DateTime.now());
    try {
      await current.player.play();
    } catch (_) {
      _promptUserGesture();
      return;
    }
    try {
      state = state?.copyWith(needsUserGesture: false);
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    final current = state;
    if (current == null) return;
    final clamped = volume.clamp(0.0, 100.0);
    if (clamped > 0) _lastVolume = clamped;
    await current.player.setVolume(clamped);
    // Re-read the state: playing/buffering events or a channel switch may have
    // landed while the volume was being applied.
    final latest = state;
    if (latest == null || latest.player != current.player) return;
    state = latest.copyWith(
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

  /// Pauses playback because the app is no longer visible. Safe to call more
  /// than once (several screens and lifecycle states may report it).
  void onAppBackgrounded() {
    if (_inBackground) return;
    _inBackground = true;
    _setWakelock(false);
    final current = state;
    if (current == null || _pausedByLifecycle) return;
    if (current.playing || _isOpening) {
      _pausedByLifecycle = true;
      try {
        unawaited(current.player.pause());
      } catch (_) {}
    }
  }

  /// Resumes playback that [onAppBackgrounded] paused.
  void onAppForegrounded() {
    if (!_inBackground) return;
    _inBackground = false;
    final current = state;
    if (current == null) return;
    _setWakelock(true);
    if (!_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    _health?.expectPlayback(DateTime.now());
    try {
      unawaited(current.player.play());
    } catch (_) {}
  }

  /// Closes the player and releases its resources.
  ///
  /// The audio-focus and connectivity listeners belong to the notifier, not to
  /// one playback session, so they stay active for the next channel.
  Future<void> close() async {
    _hideTimer?.cancel();
    _healthTimer?.cancel();
    _healthTimer = null;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    final player = state?.player;
    state = null;
    _health = null;
    _tuningReady = null;
    // Invalidate any open still in flight.
    _openSeq++;
    _isOpening = false;
    _openViaProxy = false;
    _pausedByLifecycle = false;
    _pausedByAudioInterruption = false;
    _pausedByUser = false;
    _reconnectAttempts = 0;
    _lastReconnectAt = null;

    if (player == null) {
      if (!kIsWeb) {
        try {
          await WakelockPlus.disable();
        } catch (_) {}
      }
      return;
    }

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
    if (!kIsWeb) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _healthTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _audioInterruptionSub?.cancel();
    _audioInterruptionSub = null;
    _audioNoisySub?.cancel();
    _audioNoisySub = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    final player = state?.player;
    state = null;
    if (player != null) {
      unawaited(player.stop().then((_) => player.dispose()));
    }
    if (!kIsWeb) {
      try {
        WakelockPlus.disable();
      } catch (_) {}
    }
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerSession?>(
  (ref) => PlayerNotifier(ref),
);
