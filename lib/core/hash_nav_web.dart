import 'package:web/web.dart' as web;

/// Reads the current URL hash on web (Uri.base is cached at startup).
String currentUrlHash() => web.window.location.hash;