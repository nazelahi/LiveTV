import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/playback_tuning.dart';

void main() {
  test('standard mode keeps the default buffer and no overrides', () {
    final tuning = playbackTuningFor(compatibilityMode: false);

    expect(tuning.bufferSize, 32 * 1024 * 1024);
    expect(tuning.properties, isEmpty);
  });

  test('compatibility mode uses a larger buffer and safer mpv options', () {
    final tuning = playbackTuningFor(compatibilityMode: true);

    expect(tuning.bufferSize, 64 * 1024 * 1024);
    expect(tuning.properties, {
      'hwdec': 'no',
      'network-timeout': '30',
      'demuxer-max-bytes': '67108864',
      'force-seekable': 'yes',
    });
  });
}
