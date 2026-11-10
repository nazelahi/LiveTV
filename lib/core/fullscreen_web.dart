import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Requests the browser's Fullscreen API for the document element on web.
Future<void> enterBrowserFullscreen() async {
  if (!kIsWeb) return;
  try {
    // Fire-and-forget: awaiting the promise can hang in some browsers.
    web.document.documentElement?.requestFullscreen().toDart.ignore();
  } catch (_) {
    // Ignore: not all browsers allow programmatic fullscreen.
  }
}

/// Exits the browser's Fullscreen API on web.
Future<void> exitBrowserFullscreen() async {
  if (!kIsWeb) return;
  try {
    web.document.exitFullscreen().toDart.ignore();
  } catch (_) {
    // Ignore: nothing to exit.
  }
}

/// Whether the document is currently in fullscreen.
bool isBrowserFullscreen() {
  if (!kIsWeb) return false;
  return web.document.fullscreenElement != null;
}

/// Listens for the browser exiting fullscreen (e.g. user pressed Esc).
/// Returns a cancel function the caller must invoke.
void Function()? listenFullscreenChange(void Function() onChange) {
  if (!kIsWeb) return null;
  void handler(web.Event _) => onChange();
  final listener = handler.toJS;
  web.document.addEventListener('fullscreenchange', listener);
  return () => web.document.removeEventListener('fullscreenchange', listener);
}