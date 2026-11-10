import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'stream_source.dart';

/// Probes whether a stream URL is actually playable.
///
/// This is deliberately a lightweight HTTP check rather than a full media_kit
/// open: it never decodes video, it only confirms that the server answers and
/// (for HLS) that the response looks like a playlist. Returns `true` when the
/// stream appears reachable, `false` on any error, non-2xx status or timeout.
///
/// Stream URLs may carry IPTV `|header=value&...` options; these are split out
/// and applied as HTTP headers so header-protected streams are probed correctly.
Future<bool> probeStream(
  http.Client client,
  String url, {
  Duration timeout = const Duration(seconds: 4),
  Map<String, String>? headers,
}) async {
  final source = parseStreamSource(url);
  final targetUrl = proxiedStreamUrl(source.url);

  Uri uri;
  try {
    uri = Uri.parse(targetUrl);
  } catch (_) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final requestHeaders = <String, String>{
    'User-Agent': 'VLC/3.0.20',
    'Accept': '*/*',
    ...?source.headers,
    ...?headers,
  };

  http.StreamedResponse response;
  try {
    final request = http.Request('GET', uri)..headers.addAll(requestHeaders);
    response = await client.send(request).timeout(timeout);
  } catch (_) {
    return false;
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    try {
      await response.stream.drain<void>().timeout(timeout);
    } catch (_) {}
    return false;
  }

  final contentType = (response.headers['content-type'] ?? '').toLowerCase();
  final isHls = targetUrl.toLowerCase().contains('.m3u8') ||
      contentType.contains('mpegurl') ||
      contentType.contains('x-mpegurl');

  if (!isHls) {
    // A single chunk is enough: we never need to download the whole stream.
    // The subscription created by `first` is cancelled automatically once a
    // chunk arrives, so do not call `drain` afterwards (it would try to
    // re-listen to the same single-subscription stream).
    try {
      await response.stream.first.timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // HLS: read until we see a playlist marker or the stream ends.
  final buffer = StringBuffer();
  try {
    await for (final chunk in response.stream.timeout(timeout)) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      if (buffer.toString().contains('#EXT')) return true;
      if (buffer.length > 65536) break;
    }
  } catch (_) {
    // Timeout or socket error while reading.
  }
  return buffer.toString().contains('#EXT');
}