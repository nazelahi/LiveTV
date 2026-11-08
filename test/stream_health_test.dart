import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/stream_health.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  StreamHealthMonitor monitor() => StreamHealthMonitor(
        stallAfter: const Duration(seconds: 12),
        bufferTimeout: const Duration(seconds: 20),
      );

  test('healthy playback reports ok', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(false, t0);
    m.onPlaying(true, t0);
    m.onPosition(Duration.zero, t0);
    m.onPosition(const Duration(seconds: 1), at(1));

    expect(m.check(at(10)), StreamHealth.ok);

    m.onPosition(const Duration(seconds: 2), at(11));
    expect(m.check(at(20)), StreamHealth.ok);
  });

  test('flags a stall when the position stops advancing', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(false, t0);
    m.onPlaying(true, t0);
    m.onPosition(const Duration(seconds: 5), at(1));

    expect(m.check(at(12)), StreamHealth.ok);
    expect(m.check(at(13)), StreamHealth.reconnect);
  });

  test('a new position clears the stall', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(false, t0);
    m.onPlaying(true, t0);
    m.onPosition(const Duration(seconds: 5), t0);
    m.onPosition(const Duration(seconds: 6), at(11));

    expect(m.check(at(20)), StreamHealth.ok);
  });

  test('paused playback is not treated as a stall', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(false, t0);
    m.onPlaying(true, t0);
    m.onPosition(Duration.zero, t0);
    m.onPlaying(false, at(1));

    expect(m.check(at(60)), StreamHealth.ok);
  });

  test('buffering past the timeout while opening reports timeout', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(true, at(1));

    expect(m.check(at(19)), StreamHealth.ok);
    expect(m.check(at(20)), StreamHealth.timeout);
  });

  test('autoplay-off does not arm a timeout until play is requested', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: false);
    m.onBuffering(true, at(1));

    expect(m.check(at(60)), StreamHealth.ok);

    m.expectPlayback(at(61));
    m.onBuffering(true, at(61));

    expect(m.check(at(80)), StreamHealth.ok);
    expect(m.check(at(81)), StreamHealth.timeout);
  });

  test('reset clears a pending stall', () {
    final m = monitor();
    m.beginOpen(t0, expectPlayback: true);
    m.onBuffering(false, t0);
    m.onPlaying(true, t0);
    m.onPosition(Duration.zero, t0);

    expect(m.check(at(15)), StreamHealth.reconnect);

    m.reset();
    expect(m.check(at(16)), StreamHealth.ok);
  });
}
