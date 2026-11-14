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
  ///
  /// May carry IPTV `|Header=value&...` options (see `parseStreamSource`).
  final String url;

  /// [url] without the `|` header options, for opening in another app.
  String get streamUrl {
    final pipe = url.indexOf('|');
    return pipe < 0 ? url : url.substring(0, pipe);
  }

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

/// Finds the channel a saved or shared [id] refers to. Links shared before
/// channels without a tvg-id got name-based ids carry the stream URL instead.
int indexOfChannelId(List<Channel> channels, String id) {
  final index = channels.indexWhere((c) => c.id == id);
  if (index >= 0) return index;
  return channels.indexWhere((c) => c.url == id || c.streamUrl == id);
}
