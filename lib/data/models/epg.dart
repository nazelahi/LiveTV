/// A single programme entry parsed from an XMLTV document.
class Programme {
  const Programme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
    this.icon,
    this.categories = const <String>[],
    this.isNew = false,
    this.isPremiere = false,
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;
  final String? icon;

  /// XMLTV `<category>` values, for example `Movie`, `Sport` or `News`.
  final List<String> categories;

  /// True when the XMLTV entry carries a `<new/>` flag.
  final bool isNew;

  /// True when the XMLTV entry carries a `<premiere/>` flag.
  final bool isPremiere;

  bool isLiveAt(DateTime now) => !start.isAfter(now) && stop.isAfter(now);

  bool get isLive => isLiveAt(DateTime.now());

  Duration get duration => stop.difference(start);

  @override
  String toString() => 'Programme($title, $start–$stop)';
}

/// Parsed XMLTV guide.
class EpgData {
  const EpgData({
    required this.byChannel,
    required this.fetchedAt,
    this.hasCategories = true,
  });

  /// Channel id -> programmes sorted by start time.
  final Map<String, List<Programme>> byChannel;

  final DateTime fetchedAt;

  /// True when the cache was written by a version that parses XMLTV
  /// categories. Guides cached before that change need a refresh before the
  /// featured rail can classify programmes reliably.
  final bool hasCategories;

  List<Programme> programmesFor(String channelId) =>
      byChannel[channelId] ?? const <Programme>[];

  Programme? now(String channelId) {
    final now = DateTime.now();
    for (final programme in programmesFor(channelId)) {
      if (!programme.start.isAfter(now) && programme.stop.isAfter(now)) {
        return programme;
      }
    }
    return null;
  }

  Programme? next(String channelId) {
    final now = DateTime.now();
    for (final programme in programmesFor(channelId)) {
      if (programme.start.isAfter(now)) return programme;
    }
    return null;
  }

  bool hasChannel(String channelId) => byChannel.containsKey(channelId);

  int get channelCount => byChannel.length;

  int get programmeCount =>
      byChannel.values.fold(0, (sum, list) => sum + list.length);
}