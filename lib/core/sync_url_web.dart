import 'package:web/web.dart' as web;

/// Updates the browser address bar to reflect the playing channel on web.
void syncPlaybackUrl(String? channelId) {
  final target = channelId == null ? '/' : '/#/watch/$channelId';
  try {
    web.window.history.replaceState(null, '', target);
  } catch (_) {
    // Ignore: best-effort URL sync.
  }
}
