/// Builds the absolute URL that is copied when a channel is shared.
///
/// A relative `/#/watch/<id>` link breaks once it is pasted outside the site
/// (chat apps cannot resolve it), so the site origin must be included.
String buildChannelShareUrl(String origin, String pathname, String channelId) {
  final base = Uri.parse(origin);
  return base
      .replace(
        path: pathname.isEmpty ? '/' : pathname,
        fragment: '/watch/${Uri.encodeComponent(channelId)}',
      )
      .toString();
}
