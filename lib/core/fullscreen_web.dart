import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Requests the browser's Fullscreen API for the document element on web.
Future<void> enterBrowserFullscreen() async {
  if (!kIsWeb) return;
  try {
    web.document.documentElement?.requestFullscreen();
  } catch (_) {
    // Ignore: not all browsers allow programmatic fullscreen.
  }
}

/// Exits the browser's Fullscreen API on web.
Future<void> exitBrowserFullscreen() async {
  if (!kIsWeb) return;
  try {
    web.document.exitFullscreen();
  } catch (_) {
    // Ignore: nothing to exit.
  }
}