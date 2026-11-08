/// A single live channel parsed from the M3U playlist.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.url,
    required this.group,
    this.logo,
    this.tvgId,
    this.country,
    this.language,
  });

  /// Stable identifier used for favourites and lookups.
  final String id;

  final String name;

  /// The playable stream URL.
  final String url;

  final String group;

  final String? logo;
  final String? tvgId;
  final String? country;
  final String? language;

  bool get hasLogo => logo != null && logo!.trim().isNotEmpty;

  /// Lower-cased haystack used by the search field.
  String get searchHaystack => '${name.toLowerCase()} ${group.toLowerCase()}';

  @override
  String toString() => 'Channel($name, $group)';
}
