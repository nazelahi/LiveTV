export 'playback_errors.dart';

/// What the player should do when the health check runs.
enum StreamHealth { ok, reconnect, timeout }

/// Watches playback progress and decides when a stream is stuck.
///
/// It is deliberately independent of media_kit and takes the current time as a
/// parameter, so the timing rules can be unit-tested without real timers.
class StreamHealthMonitor {
  StreamHealthMonitor({
    this.stallAfter = const Duration(seconds: 12),
    this.bufferTimeout = const Duration(seconds: 20),
  });

  final Duration stallAfter;
  final Duration bufferTimeout;

  bool _opening = false;
  bool _playing = false;
  bool _buffering = false;
  Duration? _lastPosition;
  DateTime? _positionChangedAt;
  DateTime? _bufferingSince;

  /// Arms the monitor for a newly opened stream.
  ///
  /// When autoplay is off nothing is expected yet, so no timeout fires until
  /// [expectPlayback] is called.
  void beginOpen(DateTime now, {required bool expectPlayback}) {
    _opening = expectPlayback;
    _playing = false;
    _buffering = expectPlayback;
    _bufferingSince = expectPlayback ? now : null;
    _positionChangedAt = expectPlayback ? now : null;
    _lastPosition = null;
  }

  /// Arms the timeout after the user asks playback to start.
  void expectPlayback(DateTime now) {
    _opening = true;
    _bufferingSince = _buffering ? now : null;
    _positionChangedAt = now;
  }

  void onPlaying(bool playing, DateTime now) {
    _playing = playing;
    if (playing) {
      _opening = false;
      _buffering = false;
      _bufferingSince = null;
      _positionChangedAt ??= now;
    }
  }

  void onBuffering(bool buffering, DateTime now) {
    _buffering = buffering;
    if (buffering) {
      _bufferingSince ??= now;
    } else {
      _bufferingSince = null;
      _positionChangedAt = now;
    }
  }

  void onPosition(Duration position, DateTime now) {
    if (_lastPosition == position) return;
    _lastPosition = position;
    _positionChangedAt = now;
  }

  StreamHealth check(DateTime now) {
    if (_buffering && (_opening || _playing)) {
      final since = _bufferingSince;
      if (since != null && now.difference(since) >= bufferTimeout) {
        return StreamHealth.timeout;
      }
      return StreamHealth.ok;
    }

    if (!_playing) return StreamHealth.ok;

    final changedAt = _positionChangedAt;
    if (changedAt == null) return StreamHealth.ok;
    if (now.difference(changedAt) >= stallAfter) {
      return StreamHealth.reconnect;
    }
    return StreamHealth.ok;
  }

  void reset() {
    _opening = false;
    _playing = false;
    _buffering = false;
    _lastPosition = null;
    _positionChangedAt = null;
    _bufferingSince = null;
  }
}
