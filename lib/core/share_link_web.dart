import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'share_url.dart';

Future<void> shareChannelLink(String channelId) async {
  final location = web.window.location;
  final url = buildChannelShareUrl(
    location.origin,
    location.pathname,
    channelId,
  );
  web.window.history.replaceState(null, '', url);
  await Clipboard.setData(ClipboardData(text: url));
}
