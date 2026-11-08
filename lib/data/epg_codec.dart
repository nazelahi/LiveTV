import 'dart:convert';

import '../data/models/epg.dart';

const int _epgCacheVersion = 1;

String encodeEpg(EpgData data) {
  return jsonEncode({
    'v': _epgCacheVersion,
    if (data.hasCategories) 'hc': 1,
    'fetchedAt': data.fetchedAt.toIso8601String(),
    'channels': {
      for (final entry in data.byChannel.entries)
        entry.key: [
          for (final programme in entry.value)
            {
              't': programme.title,
              's': programme.start.toIso8601String(),
              'e': programme.stop.toIso8601String(),
              if (programme.description != null) 'd': programme.description,
              if (programme.icon != null) 'i': programme.icon,
              if (programme.categories.isNotEmpty) 'c': programme.categories,
              if (programme.isNew) 'n': 1,
              if (programme.isPremiere) 'p': 1,
            },
        ],
    },
  });
}

EpgData? decodeEpg(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['v'] != _epgCacheVersion) return null;

    final fetchedAtRaw = decoded['fetchedAt'];
    final fetchedAt = fetchedAtRaw is String
        ? DateTime.tryParse(fetchedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final channelsRaw = decoded['channels'];
    if (channelsRaw is! Map) return null;

    final byChannel = <String, List<Programme>>{};
    for (final entry in channelsRaw.entries) {
      final channelId = entry.key;
      if (channelId is! String) continue;
      final list = entry.value;
      if (list is! List) continue;
      final programmes = <Programme>[];
      for (final item in list) {
        if (item is! Map) continue;
        final title = item['t'];
        final startRaw = item['s'];
        final stopRaw = item['e'];
        if (title is! String || startRaw is! String || stopRaw is! String) {
          continue;
        }
        final start = DateTime.tryParse(startRaw);
        final stop = DateTime.tryParse(stopRaw);
        if (start == null || stop == null) continue;
        final categoriesRaw = item['c'];
        programmes.add(
          Programme(
            channelId: channelId,
            title: title,
            start: start,
            stop: stop,
            description: item['d'] is String ? item['d'] as String : null,
            icon: item['i'] is String ? item['i'] as String : null,
            categories: categoriesRaw is List
                ? categoriesRaw.whereType<String>().toList(growable: false)
                : const <String>[],
            isNew: item['n'] == 1 || item['n'] == true,
            isPremiere: item['p'] == 1 || item['p'] == true,
          ),
        );
      }
      programmes.sort((a, b) => a.start.compareTo(b.start));
      if (programmes.isNotEmpty) {
        byChannel[channelId] = programmes;
      }
    }

    return EpgData(
      byChannel: byChannel,
      fetchedAt: fetchedAt,
      hasCategories: decoded['hc'] == 1,
    );
  } on FormatException {
    return null;
  }
}