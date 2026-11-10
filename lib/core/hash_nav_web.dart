import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Registers a listener for same-document hash changes on web.
void registerHashChangeListener(void Function() handler) {
  final cb = ((web.Event _) {
    handler();
  }).toJS;
  web.window.addEventListener('hashchange', cb);
}

/// Reads the current URL hash on web (Uri.base is cached at startup).
String currentUrlHash() => web.window.location.hash;