import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'epg_codec.dart';
import 'epg_parser.dart';
import 'hive_store.dart';
import 'models/epg.dart';

class EpgRepository {
  EpgRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Reads the last guide saved on this device, if any.
  EpgData? readCache() {
    final box = HiveStore.epg;
    final raw = box.get(HiveStore.epgDataKey);
    if (raw == null || raw.isEmpty) return null;
    return decodeEpg(raw);
  }

  /// Synchronous variant for startup.
  EpgData? readCacheSync() => readCache();

  /// Downloads the guide from [AppConfig.epgUrl] and caches it.
  Future<EpgData> fetch() async {
    final response = await _client
        .get(
          Uri.parse(AppConfig.epgUrl),
          headers: kIsWeb
              ? const <String, String>{}
              : const <String, String>{'Cache-Control': 'no-cache'},
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw EpgException(
        'The EPG server returned HTTP ${response.statusCode}.',
      );
    }

    final parsed = kIsWeb
        ? await parseEpgChunked(response.bodyBytes)
        : await compute(parseEpgBytes, response.bodyBytes);

    if (parsed.channelCount == 0) {
      throw const EpgException('The downloaded guide did not contain any programmes.');
    }

    await _saveCache(parsed);
    return parsed;
  }

  Future<void> _saveCache(EpgData data) async {
    final box = HiveStore.epg;
    await box.put(HiveStore.epgDataKey, encodeEpg(data));
    await box.put(
      HiveStore.epgUpdatedAtKey,
      data.fetchedAt.toIso8601String(),
    );
  }

  DateTime? cachedUpdatedAt() {
    final raw = HiveStore.epg.get(HiveStore.epgUpdatedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearCache() async {
    await HiveStore.epg.clear();
  }

  void dispose() {
    _client.close();
  }
}

class EpgException implements Exception {
  const EpgException(this.message);

  final String message;

  @override
  String toString() => message;
}