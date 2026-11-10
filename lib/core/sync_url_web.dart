import 'package:web/web.dart' as web;

/// Updates the browser address bar to reflect the playing channel on web.
void syncPlaybackUrl(String? channelId) {
  final location = web.window.location;
  final basePath = location.pathname.isEmpty ? '/' : location.pathname;
  final target = channelId == null
      ? basePath
      : Uri(path: basePath, fragment: '/watch/${Uri.encodeComponent(channelId)}').toString();
  try {
    web.window.history.replaceState(null, '', target);
  } catch (_) {
    // Ignore: best-effort URL sync.
  }
}