import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<void> shareChannelLink(String channelId) async {
  final location = web.window.location;
  final basePath = location.pathname.isEmpty ? '/' : location.pathname;
  final url = Uri(
    path: basePath,
    fragment: '/watch/${Uri.encodeComponent(channelId)}',
  ).toString();
  web.window.history.replaceState(null, '', url);
  await Clipboard.setData(ClipboardData(text: url));
}