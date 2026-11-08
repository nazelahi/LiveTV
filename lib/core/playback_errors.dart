/// Helpers for classifying playback errors reported by media_kit/libmpv.
///
/// BDIX streams frequently emit transient `tcp`/`ffurl` errors that are not
/// actually dead channels, so callers can bypass them instead of failing.
bool isTransientStreamError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('tcp') || lower.contains('ffurl');
}

/// Alias for [isTransientStreamError].
bool isTransientPlaybackError(String raw) => isTransientStreamError(raw);

/// Alias for [isTransientStreamError].
bool isTransientTcpOrFfurlError(String raw) => isTransientStreamError(raw);

/// Alias for [isTransientStreamError].
bool isBypassableStreamError(String raw) => isTransientStreamError(raw);

/// Alias for [isTransientStreamError].
bool shouldBypassStreamError(String raw) => isTransientStreamError(raw);

/// Alias for [isTransientStreamError].
bool isIgnorableStreamError(String raw) => isTransientStreamError(raw);

/// Alias for [isTransientStreamError].
bool isIgnorablePlaybackError(String raw) => isTransientStreamError(raw);

/// Turns a raw player error into a short, user-facing message.
String friendlyPlaybackError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('404')) return 'Channel not found (HTTP 404).';
  if (lower.contains('403')) return 'Channel refused access (HTTP 403).';
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The stream timed out.';
  }
  if (lower.contains('failed to open') || lower.contains('unable to open')) {
    return 'Could not open this stream.';
  }
  return raw;
}

/// Alias for [friendlyPlaybackError].
String friendlyError(String raw) => friendlyPlaybackError(raw);

/// Alias for [friendlyPlaybackError].
String friendlyPlaybackMessage(String raw) => friendlyPlaybackError(raw);