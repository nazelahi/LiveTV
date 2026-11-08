import 'channel.dart';

/// The parsed playlist plus metadata about where it came from.
class PlaylistState {
  const PlaylistState({
    required this.channels,
    required this.groups,
    required this.updatedAt,
    required this.fromCache,
  });

  final List<Channel> channels;

  /// Group names in the order they first appear in the playlist.
  final List<String> groups;

  final DateTime? updatedAt;

  /// True when this snapshot was read from local storage instead of the network.
  final bool fromCache;

  bool get isEmpty => channels.isEmpty;
}

/// Result of parsing an M3U document on a background isolate.
class ParsedPlaylist {
  const ParsedPlaylist({required this.channels, required this.groups});

  final List<Channel> channels;
  final List<String> groups;
}
