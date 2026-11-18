import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'providers/playlist_providers.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/deep_link_watch_screen.dart';

class LiveTvApp extends ConsumerStatefulWidget {
  const LiveTvApp({super.key});

  @override
  ConsumerState<LiveTvApp> createState() => _LiveTvAppState();
}

class _LiveTvAppState extends ConsumerState<LiveTvApp>
    with WidgetsBindingObserver {
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Background auto-sync: while the app is open, re-check the admin config
    // periodically so a playlist published from the admin panel appears
    // without the user having to refresh manually.
    _autoSyncTimer = Timer.periodic(AppConfig.staleAfter, (_) => _autoSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app came back from the background (or the browser tab became
    // visible again): check whether the admin published a new playlist.
    if (state == AppLifecycleState.resumed) _autoSync();
  }

  /// Cheap non-forced check: one small config request; the playlist is
  /// downloaded only when the admin changed the version or the sources.
  Future<void> _autoSync() async {
    try {
      await ref
          .read(playlistProvider.notifier)
          .refresh(force: false, background: true);
    } catch (_) {
      // Offline or config unreachable: keep showing the cached playlist.
    }
  }

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
