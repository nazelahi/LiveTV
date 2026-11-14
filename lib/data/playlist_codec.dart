import 'dart:convert';

import 'models/channel.dart';
import 'models/playlist_state.dart';

/// Bump when the cached shape changes so old cache is ignored and re-parsed.
/// 2: name-based ids for channels without a tvg-id, #EXTVLCOPT headers.
const int _cacheVersion = 2;

/// Encodes a parsed playlist so the next launch can skip M3U parsing.
String encodeParsedPlaylist(ParsedPlaylist playlist) {
  return jsonEncode({
    'v': _cacheVersion,
    'groups': playlist.groups,
    'channels': [
      for (final channel in playlist.channels)
        {
          'id': channel.id,
          'name': channel.name,
          'url': channel.url,
          'group': channel.group,
          'logo': channel.logo,
          'tvgId': channel.tvgId,
          'country': channel.country,
          'language': channel.language,
        },
    ],
  });
}

/// Decodes [encodeParsedPlaylist] output, or returns null when it is missing,
/// malformed, from another version, or shaped unexpectedly.
ParsedPlaylist? decodeParsedPlaylist(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> || decoded['v'] != _cacheVersion) {
      return null;
    }

    final groupsRaw = decoded['groups'];
    final channelsRaw = decoded['channels'];
    if (groupsRaw is! List || channelsRaw is! List) return null;

    final groups = <String>[];
    for (final group in groupsRaw) {
      if (group is! String) return null;
      groups.add(group);
    }

    final channels = <Channel>[];
    for (final item in channelsRaw) {
      if (item is! Map) return null;

      final id = item['id'];
      final name = item['name'];
      final url = item['url'];
      final group = item['group'];
      if (id is! String || name is! String || url is! String || group is! String) {
        return null;
      }

      channels.add(
        Channel(
          id: id,
          name: name,
          url: url,
          group: group,
          logo: _stringOrNull(item['logo']),
          tvgId: _stringOrNull(item['tvgId']),
          country: _stringOrNull(item['country']),
          language: _stringOrNull(item['language']),
        ),
      );
    }

    return ParsedPlaylist(channels: channels, groups: groups);
  } on FormatException {
    return null;
  }
}

String? _stringOrNull(Object? value) => value is String ? value : null;
