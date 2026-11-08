export 'playback_errors.dart';

/// A playable stream URL with any IPTV `|header=value&...` options split out.
class StreamSource {
  const StreamSource({required this.url, this.headers});

  /// The URL to hand to the player, without the `|` options suffix.
  final String url;

  /// Parsed `Key=Value` pairs from the suffix, or null when there are none.
  final Map<String, String>? headers;
}

/// Splits the common `url|User-Agent=...&Referer=...` IPTV convention.
///
/// The pipe and everything after it are player options, not part of the URL.
/// Malformed parts (no `=`, empty key) are ignored.
StreamSource parseStreamSource(String raw) {
  final pipe = raw.indexOf('|');
  if (pipe < 0) return StreamSource(url: raw);

  final url = raw.substring(0, pipe);
  final headers = <String, String>{};

  for (final part in raw.substring(pipe + 1).split('&')) {
    final equals = part.indexOf('=');
    if (equals <= 0) continue;

    final key = part.substring(0, equals).trim();
    if (key.isEmpty) continue;

    headers[key] = part.substring(equals + 1);
  }

  return StreamSource(url: url, headers: headers.isEmpty ? null : headers);
}
