import 'constants.dart';

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
  if (lower.contains('401')) return 'Channel requires authentication (HTTP 401).';
  if (lower.contains('500') || lower.contains('502') || lower.contains('503')) {
    return 'The stream server is unavailable. Try again later.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The stream timed out.';
  }
  if (lower.contains('failed to open') || lower.contains('unable to open')) {
    return 'Could not open this stream.';
  }
  if (lower.contains('unsupported') || lower.contains('codec')) {
    return 'This stream uses an unsupported format.';
  }
  if (lower.contains('network') || lower.contains('connection refused') ||
      lower.contains('no route')) {
    return 'Network error. Check your connection.';
  }
  if (lower.contains('ssl') || lower.contains('certificate')) {
    return 'Secure connection failed for this stream.';
  }
  // Keep the message short for the UI.
  if (raw.length > AppConfig.maxErrorMessageLength) {
    return '${raw.substring(0, AppConfig.maxErrorMessageLength)}…';
  }
  return raw;
}

/// Alias for [friendlyPlaybackError].
String friendlyError(String raw) => friendlyPlaybackError(raw);

/// Alias for [friendlyPlaybackError].
String friendlyPlaybackMessage(String raw) => friendlyPlaybackError(raw);