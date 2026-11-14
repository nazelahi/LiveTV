import 'models/channel.dart';
import 'models/playlist_state.dart';

final RegExp _attributePattern = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

/// Parses an Extended M3U playlist into channels.
///
/// This is deliberately dependency-free and top-level so it can run inside
/// [compute] on a background isolate for large playlists.
ParsedPlaylist parseM3u(String content) {
  final channels = <Channel>[];
  final groups = <String>[];
  final seenGroups = <String>{};
  final seenIds = <String>{};

  Map<String, String>? attributes;
  String? displayName;
  var pendingGroup = '';
  // #EXTVLCOPT http options for the next stream URL.
  final pendingOptions = <String, String>{};

  final lines = content.split(RegExp(r'\r?\n'));

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      final splitIndex = _nameSeparatorIndex(line);
      final header =
          splitIndex >= 0 ? line.substring(0, splitIndex) : line;
      displayName =
          splitIndex >= 0
              ? _stripQuotes(line.substring(splitIndex + 1).trim())
              : '';

      attributes = <String, String>{};
      for (final match in _attributePattern.allMatches(header)) {
        attributes[match.group(1)!.toLowerCase()] = match.group(2)!;
      }
      continue;
    }

    if (line.startsWith('#EXTGRP:')) {
      pendingGroup = line.substring('#EXTGRP:'.length).trim();
      continue;
    }

    if (line.startsWith('#EXTVLCOPT:')) {
      final option = line.substring('#EXTVLCOPT:'.length);
      final equals = option.indexOf('=');
      if (equals > 0) {
        final header =
            _vlcOptionHeaders[option.substring(0, equals).trim().toLowerCase()];
        final value = option.substring(equals + 1).trim();
        if (header != null && value.isNotEmpty) pendingOptions[header] = value;
      }
      continue;
    }

    // Any other directive (#KODIPROP, comments) is ignored.
    if (line.startsWith('#')) continue;

    if (attributes == null) {
      pendingOptions.clear();
      continue;
    }

    final name = _firstNonEmpty([
      displayName,
      attributes['tvg-name'],
      attributes['channel-id'],
      attributes['tvg-id'],
    ], fallback: 'Unknown channel');

    final group = _firstNonEmpty([
      attributes['group-title'],
      pendingGroup,
    ], fallback: 'Uncategorised');

    final tvgId = (attributes['tvg-id'] ?? '').trim();
    // Stream URLs often carry rotating tokens, so without a tvg-id the id is
    // derived from the name and group: favourites and deep links then survive
    // a URL change.
    var id = tvgId.isNotEmpty ? tvgId : nameBasedChannelId(name, group);
    if (!seenIds.add(id)) {
      var suffix = 2;
      while (!seenIds.add('$id#$suffix')) {
        suffix++;
      }
      id = '$id#$suffix';
    }

    final logo = (attributes['tvg-logo'] ?? '').trim();

    channels.add(
      Channel(
        id: id,
        name: name,
        url: _withOptions(line, pendingOptions),
        group: group,
        logo: logo.isEmpty ? null : logo,
        tvgId: tvgId.isEmpty ? null : tvgId,
        country: _nullIfEmpty(attributes['tvg-country']),
        language: _nullIfEmpty(attributes['tvg-language']),
      ),
    );

    if (seenGroups.add(group)) {
      groups.add(group);
    }

    attributes = null;
    displayName = null;
    pendingGroup = '';
    pendingOptions.clear();
  }

  return ParsedPlaylist(channels: channels, groups: groups);
}

/// The id given to a channel without a tvg-id.
String nameBasedChannelId(String name, String group) =>
    '${group.trim().toLowerCase()}/${name.trim().toLowerCase()}';

/// VLC options that map onto HTTP request headers.
const Map<String, String> _vlcOptionHeaders = {
  'http-user-agent': 'User-Agent',
  'http-referrer': 'Referer',
  'http-referer': 'Referer',
  'http-origin': 'Origin',
  'http-cookie': 'Cookie',
};

/// Appends [options] using the `url|Header=value&...` convention understood
/// by `parseStreamSource`. Headers already on the URL win.
String _withOptions(String url, Map<String, String> options) {
  if (options.isEmpty) return url;
  final pipe = url.indexOf('|');
  final existing = pipe < 0 ? '' : url.substring(pipe + 1);
  final present = existing
      .split('&')
      .map((part) => part.split('=').first.trim().toLowerCase())
      .where((key) => key.isNotEmpty)
      .toSet();
  final extra = [
    for (final entry in options.entries)
      if (!present.contains(entry.key.toLowerCase()))
        '${entry.key}=${entry.value}',
  ];
  if (extra.isEmpty) return url;
  if (pipe < 0) return '$url|${extra.join('&')}';
  final separator = existing.isEmpty ? '' : '&';
  return '$url$separator${extra.join('&')}';
}

/// Removes symmetric surrounding quotes some playlists put around the whole
/// display name (`#EXTINF:-1,"Name, with comma"`), which the comma split
/// leaves intact.
String _stripQuotes(String name) {
  if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
    return name.substring(1, name.length - 1).trim();
  }
  return name;
}

String _firstNonEmpty(List<String?> values, {required String fallback}) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Finds the comma that separates EXTINF attributes from the display name.
///
/// Attribute values can legally contain commas, and display names can contain
/// quotes, so the split happens at the first comma outside a quoted value.
int _nameSeparatorIndex(String line) {
  var start = line.indexOf(':');
  if (start < 0) start = 0;
  var inQuotes = false;
  for (var i = start; i < line.length; i++) {
    final char = line.codeUnitAt(i);
    if (char == 0x22) {
      inQuotes = !inQuotes;
    } else if (char == 0x2C && !inQuotes) {
      return i;
    }
  }
  return -1;
}
