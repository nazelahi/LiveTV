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

  final lines = content.split(RegExp(r'\r?\n'));

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      final splitIndex = _nameSeparatorIndex(line);
      final header =
          splitIndex >= 0 ? line.substring(0, splitIndex) : line;
      displayName =
          splitIndex >= 0 ? line.substring(splitIndex + 1).trim() : '';

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

    // Any other directive (#EXTVLCOPT, #KODIPROP, comments) is ignored.
    if (line.startsWith('#')) continue;

    if (attributes == null) continue;

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
    var id = tvgId.isNotEmpty ? tvgId : line;
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
        url: line,
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
  }

  return ParsedPlaylist(channels: channels, groups: groups);
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
/// Attribute values can legally contain commas, so the split happens after the
/// last closing quote when attributes are present.
int _nameSeparatorIndex(String line) {
  final lastQuote = line.lastIndexOf('"');
  final start = lastQuote >= 0 ? lastQuote + 1 : line.indexOf(':');
  if (start < 0) return line.indexOf(',');
  return line.indexOf(',', start);
}
