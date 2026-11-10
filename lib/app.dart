import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/deep_link_watch_screen.dart';

class LiveTvApp extends StatelessWidget {
  const LiveTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: kIsWeb ? const RootScreen() : const SplashScreen(),
      onGenerateRoute: kIsWeb
          ? (settings) => _routeForDeepLink(settings)
          : null,
    );
  }
}

/// Parses a `#/watch/<id>` (or `/watch/<id>`) deep link into a watch route.
/// Returns null for anything else so Flutter falls back to the home route.
Route<dynamic>? _routeForDeepLink(RouteSettings settings) {
  final name = settings.name;
  if (name == null || name.isEmpty) return null;
  final id = parseWatchDeepLink(name);
  if (id == null) return null;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => DeepLinkWatchScreen(channelId: id),
  );
}