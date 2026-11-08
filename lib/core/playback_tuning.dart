/// Playback tuning applied when a [media_kit] player is created.
class PlaybackTuning {
  const PlaybackTuning({required this.bufferSize, required this.properties});

  /// Demuxer cache size passed to media_kit.
  final int bufferSize;

  /// libmpv properties applied after the player is ready.
  final Map<String, String> properties;
}

const int standardBufferSize = 32 * 1024 * 1024;
const int compatibilityBufferSize = 64 * 1024 * 1024;

/// Standard mode keeps media_kit's defaults.
///
/// Compatibility mode disables hardware decoding (some TS/H.264 streams fail
/// with it), gives libmpv a larger demuxer cache, and a longer network timeout.
PlaybackTuning playbackTuningFor({required bool compatibilityMode}) {
  if (!compatibilityMode) {
    return const PlaybackTuning(
      bufferSize: standardBufferSize,
      properties: {},
    );
  }

  return const PlaybackTuning(
    bufferSize: compatibilityBufferSize,
    properties: {
      'hwdec': 'no',
      'network-timeout': '30',
      'demuxer-max-bytes': '$compatibilityBufferSize',
      'force-seekable': 'yes',
    },
  );
}
