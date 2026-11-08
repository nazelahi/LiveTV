import 'channel.dart';

/// The parsed playlist plus metadata about where it came from.
class PlaylistState {
  const PlaylistState({
    required this.channels,
    required this.groups,
    required this.updatedAt,
    required this.fromCache,
    this.failedSources = const <String>[],
  });

  final List<Channel> channels;

  /// Group names in the order they first appear in the playlist.
  final List<String> groups;

  final DateTime? updatedAt;

  /// True when this snapshot was read from local storage instead of the network.
  final bool fromCache;

  /// Playlist URLs that could not be loaded during the last fetch. Empty when
  /// everything succeeded (or when read from cache).
  final List<String> failedSources;

  bool get isEmpty => channels.isEmpty;

  bool get hasFailures => failedSources.isNotEmpty;
}

/// Result of parsing an M3U document on a background isolate.
class ParsedPlaylist {
  const ParsedPlaylist({required this.channels, required this.groups});

  final List<Channel> channels;
  final List<String> groups;
}
