import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<void> shareChannelLink(String channelId) async {
  final url = '${web.window.location.origin}/#/watch/$channelId';
  // Use replaceState so we update the address bar without triggering Flutter's
  // hash-based router.
  web.window.history.replaceState(null, '', '/#/watch/$channelId');
  await Clipboard.setData(ClipboardData(text: url));
}