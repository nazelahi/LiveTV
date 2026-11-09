import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'hive_store.dart';
import 'm3u_parser.dart';
import 'models/channel.dart';
import 'models/playlist_state.dart';
import 'playlist_codec.dart';

class PlaylistRepository {
  PlaylistRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Reads and parses the last playlist saved on this device.
  Future<PlaylistState?> readCache() async {
    final box = HiveStore.cache;
    final raw = box.get(HiveStore.playlistRawKey);
    if (raw == null || raw.isEmpty) return null;

    var parsed = _readParsedCache(box);
    if (parsed == null) {
      final raws = _decodeRawList(raw);
      if (raws.isEmpty) return null;

      final parsedParts = await Future.wait(
        raws.map((item) => compute(parseM3u, item)),
      );
      parsed = mergePlaylists(parsedParts);
      if (parsed.channels.isEmpty) return null;
      _rememberParsed(box, parsed);
    }

    return _stateFrom(parsed, box, fromCache: true);
  }

  /// Downloads the playlist from the (possibly remote-configured) URL and caches it.
  ///
  /// If the config endpoint is unreachable, the last URL that worked is reused
  /// instead of silently falling back to the built-in default.
  Future<PlaylistState> fetch() async {
    final config = await _fetchConfig();
    var urls = config?.urls ?? _cachedUrls() ?? <String>[AppConfig.playlistUrl];
    if (urls.isEmpty) urls = <String>[AppConfig.playlistUrl];
    final version = config?.version;

    final rawParts = <String>[];
    final parsedParts = <ParsedPlaylist>[];
    final failed = <String>[];

    final results = await Future.wait(
      urls.map((url) async {
        try {
          final response = await _client
              .get(
                Uri.parse(url),
                headers: kIsWeb
                    ? const <String, String>{}
                    : const <String, String>{'Cache-Control': 'no-cache'},
              )
              .timeout(AppConfig.networkTimeout);

          if (response.statusCode != 200) {
            return _FetchResult(url: url, error: 'HTTP ${response.statusCode}');
          }

          final raw = utf8.decode(response.bodyBytes);
          final parsed = await compute(parseM3u, raw);

          if (parsed.channels.isEmpty) {
            return _FetchResult(url: url, error: 'no channels');
          }

          return _FetchResult(url: url, raw: raw, parsed: parsed);
        } catch (error) {
          return _FetchResult(url: url, error: '$error');
        }
      }),
    );

    for (final result in results) {
      if (result.parsed != null && result.raw != null) {
        rawParts.add(result.raw!);
        parsedParts.add(result.parsed!);
      } else {
        failed.add(result.url);
      }
    }

    if (parsedParts.isEmpty) {
      final failedList = failed.join(', ');
      throw PlaylistException(
        failedList.isEmpty
            ? 'No playlists could be loaded.'
            : 'No playlists could be loaded. Failed: $failedList',
      );
    }

    final merged = mergePlaylists(parsedParts);

    await _saveCache(rawParts, merged, urls: urls, version: version);

    return PlaylistState(
      channels: merged.channels,
      groups: merged.groups,
      updatedAt: DateTime.now(),
      fromCache: false,
      failedSources: failed,
    );
  }

  /// Public accessor for the remote config (playlist + banner fields).
  Future<RemoteConfig?> fetchRemoteConfig() => _fetchConfig();

  /// Fetches remote config, if configured. Returns null on any failure so the
  /// app falls back to the built-in playlist URL.
  Future<RemoteConfig?> _fetchConfig() async {
    if (AppConfig.configUrl.isEmpty) return null;
    try {
      final response = await _client
          .get(Uri.parse(AppConfig.configUrl))
          .timeout(AppConfig.networkTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;

      var urls = <String>[];
      final rawUrls = decoded['playlistUrls'];
      if (rawUrls is List) {
        urls = rawUrls
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
      if (urls.isEmpty) {
        final single = decoded['playlistUrl'];
        if (single is String && single.trim().isNotEmpty) {
          urls = <String>[single.trim()];
        }
      }
      if (urls.isEmpty) return null;

      final version = decoded['version'];
      bool? androidEnabled;
      final rawEnabled = decoded['androidDownloadEnabled'];
      if (rawEnabled is bool) {
        androidEnabled = rawEnabled;
      } else if (rawEnabled is String) {
        final v = rawEnabled.trim().toLowerCase();
        if (v == 'true') androidEnabled = true;
        if (v == 'false') androidEnabled = false;
      }
      String? str(dynamic v) =>
          v is String && v.trim().isNotEmpty ? v.trim() : null;
      return RemoteConfig(
        urls: urls,
        version: version is int ? version : int.tryParse('$version'),
        androidDownloadEnabled: androidEnabled,
        androidDownloadUrl: str(decoded['androidDownloadUrl']),
        androidDownloadVersion: str(decoded['androidDownloadVersion']),
        androidDownloadTitle: str(decoded['androidDownloadTitle']),
        androidDownloadSubtitle: str(decoded['androidDownloadSubtitle']),
        androidDownloadButton: str(decoded['androidDownloadButton']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads only when the remote version differs from the cached one.
  /// Returns null when the cached playlist is already up to date.
  Future<PlaylistState?> fetchIfUpdated() async {
    final config = await _fetchConfig();
    if (config != null) {
      final cachedVersion = _cachedVersion();
      if (cachedVersion != null && config.version == cachedVersion) {
        return null;
      }
    }
    return fetch();
  }

  Future<void> _saveCache(
    List<String> raws,
    ParsedPlaylist parsed, {
    required List<String> urls,
    int? version,
  }) async {
    final box = HiveStore.cache;
    await box.put(HiveStore.playlistRawKey, jsonEncode(raws));
    await box.put(
      HiveStore.playlistParsedKey,
      encodeParsedPlaylist(parsed),
    );
    await box.put(
      HiveStore.playlistUpdatedAtKey,
      DateTime.now().toIso8601String(),
    );
    await box.put(HiveStore.playlistUrlKey, jsonEncode(urls));
    if (version != null) {
      await box.put(HiveStore.playlistVersionKey, version.toString());
    }
  }

  int? _cachedVersion() {
    final raw = HiveStore.cache.get(HiveStore.playlistVersionKey);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  List<String>? _cachedUrls() => cachedUrls();

  static List<String>? cachedUrls() {
    final raw = HiveStore.cache.get(HiveStore.playlistUrlKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final urls = decoded
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
        return urls.isEmpty ? null : urls;
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return <String>[decoded.trim()];
      }
    } catch (_) {
      // Legacy single-string cache.
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : <String>[trimmed];
  }

  /// Merges multiple parsed playlists into one, deduplicating channels by
  /// case-insensitive `name|group` (first occurrence wins) and collapsing
  /// groups case-insensitively (first spelling kept).
  static ParsedPlaylist mergePlaylists(List<ParsedPlaylist> playlists) {
    final channels = <Channel>[];
    final groups = <String>[];
    final seenChannels = <String>{};
    final seenGroups = <String>{};

    for (final playlist in playlists) {
      for (final group in playlist.groups) {
        final key = group.toLowerCase();
        if (seenGroups.add(key)) {
          groups.add(group);
        }
      }
      for (final channel in playlist.channels) {
        final key = '${channel.name.toLowerCase()}|${channel.group.toLowerCase()}';
        if (seenChannels.add(key)) {
          channels.add(channel);
        }
      }
    }

    return ParsedPlaylist(channels: channels, groups: groups);
  }

  /// Synchronous variant used at startup so the first frame can show the cached
  /// channel list without waiting for an isolate round-trip.
  ///
  /// It reads the parsed cache written by a previous run. Only when that is
  /// missing (first launch after upgrading) does it parse the raw M3U once.
  PlaylistState? readCacheSync() {
    final box = HiveStore.cache;
    final raw = box.get(HiveStore.playlistRawKey);
    if (raw == null || raw.isEmpty) return null;

    final parsed = _readParsedCache(box) ?? _parseRaw(box, raw);
    return _stateFrom(parsed, box, fromCache: true);
  }

  ParsedPlaylist? _readParsedCache(Box<String> box) {
    final encoded = box.get(HiveStore.playlistParsedKey);
    if (encoded == null || encoded.isEmpty) return null;

    final parsed = decodeParsedPlaylist(encoded);
    if (parsed == null || parsed.channels.isEmpty) return null;
    return parsed;
  }

  ParsedPlaylist? _parseRaw(Box<String> box, String raw) {
    final raws = _decodeRawList(raw);
    if (raws.isEmpty) return null;

    final merged = mergePlaylists(raws.map(parseM3u).toList());
    if (merged.channels.isEmpty) return null;
    _rememberParsed(box, merged);
    return merged;
  }

  static List<String> _decodeRawList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
      if (decoded is String && decoded.isNotEmpty) {
        return <String>[decoded];
      }
    } catch (_) {
      // Legacy single raw playlist string.
    }
    return <String>[raw];
  }

  /// Writes the parsed cache in the background so the next launch is fast.
  void _rememberParsed(Box<String> box, ParsedPlaylist parsed) {
    box.put(HiveStore.playlistParsedKey, encodeParsedPlaylist(parsed)).ignore();
  }

  PlaylistState? _stateFrom(
    ParsedPlaylist? parsed,
    Box<String> box, {
    required bool fromCache,
  }) {
    if (parsed == null) return null;

    final updatedAtRaw = box.get(HiveStore.playlistUpdatedAtKey);
    return PlaylistState(
      channels: parsed.channels,
      groups: parsed.groups,
      updatedAt:
          updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw),
      fromCache: fromCache,
    );
  }

  Future<void> clearCache() async {
    await HiveStore.cache.clear();
  }

  void dispose() {
    _client.close();
  }

  /// Groups the channels by their group title, keeping playlist order.
  static Map<String, List<Channel>> groupChannels(List<Channel> channels) {
    final result = <String, List<Channel>>{};
    for (final channel in channels) {
      result.putIfAbsent(channel.group, () => <Channel>[]).add(channel);
    }
    return result;
  }
}

class RemoteConfig {
  const RemoteConfig({
    required this.urls,
    this.version,
    this.androidDownloadEnabled,
    this.androidDownloadUrl,
    this.androidDownloadVersion,
    this.androidDownloadTitle,
    this.androidDownloadSubtitle,
    this.androidDownloadButton,
  });

  final List<String> urls;
  final int? version;

  final bool? androidDownloadEnabled;
  final String? androidDownloadUrl;
  final String? androidDownloadVersion;
  final String? androidDownloadTitle;
  final String? androidDownloadSubtitle;
  final String? androidDownloadButton;

  String get url => urls.isNotEmpty ? urls.first : '';
}

class _FetchResult {
  const _FetchResult({required this.url, this.raw, this.parsed, this.error});

  final String url;
  final String? raw;
  final ParsedPlaylist? parsed;
  final String? error;
}

class PlaylistException implements Exception {
  const PlaylistException(this.message);

  final String message;

  @override
  String toString() => message;
}
