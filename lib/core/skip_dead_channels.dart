import '../data/models/channel.dart';

/// Finds the next channel after [currentIndex] that has not failed.
///
/// Wraps around the list and returns null when only the current channel is
/// left. [idAt] maps an index to its channel id.
int? nextWorkingIndex({
  required int currentIndex,
  required int length,
  required Set<String> failedIds,
  required String Function(int index) idAt,
}) {
  if (length < 2) return null;

  for (var step = 1; step < length; step++) {
    final index = (currentIndex + step) % length;
    if (!failedIds.contains(idAt(index))) return index;
  }
  return null;
}

/// Returns the channels from [channels] whose id is not in [deadIds].
///
/// Used by the home/favourites lists to hide streams that the startup probe
/// (or a previous playback failure) has marked as broken. The original order
/// is preserved.
List<Channel> filterAliveChannels(
  List<Channel> channels,
  Set<String> deadIds,
) {
  if (deadIds.isEmpty) return List<Channel>.of(channels);
  return channels
      .where((channel) => !deadIds.contains(channel.id))
      .toList(growable: false);
}

/// Alias kept for callers that prefer the "working" wording.
List<Channel> filterWorkingChannels(
  List<Channel> channels,
  Set<String> deadIds,
) =>
    filterAliveChannels(channels, deadIds);

/// Returns only the channels whose id is in [deadIds].
///
/// Unlike [filterAliveChannels], which drops dead channels, this keeps them so
/// callers can inspect or retry the broken streams. The original order is
/// preserved.
List<Channel> filterDeadChannels(
  List<Channel> channels,
  Set<String> deadIds,
) {
  if (deadIds.isEmpty) return const <Channel>[];
  return channels
      .where((channel) => deadIds.contains(channel.id))
      .toList(growable: false);
}

/// Alias kept for callers that prefer the "hide" wording.
List<Channel> hideDeadChannels(
  List<Channel> channels,
  Set<String> deadIds,
) =>
    filterAliveChannels(channels, deadIds);
