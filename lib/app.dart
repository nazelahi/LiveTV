import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';

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
      // On web, skip the splash screen and render the app shell immediately;
      // storage/media init already happened in main().
      home: kIsWeb ? const RootScreen() : const SplashScreen(),
      // Deep links are handled by RootScreen._consumeDeepLink. Provide a
      // non-null route generator so Flutter's web router does not crash with
      // "Null check operator used on a null value" when the initial URL
      // contains a hash route (e.g. a shared watch link).
      onGenerateRoute: kIsWeb
          ? (settings) => _DeepLinkPlaceholderRoute(settings)
          : null,
      navigatorObservers:
          kIsWeb ? [_DeepLinkPlaceholderObserver()] : const <NavigatorObserver>[],
    );
  }
}

/// A route that only exists to satisfy Flutter's web router for hash URLs.
/// It renders nothing and removes itself as soon as it is on top.
class _DeepLinkPlaceholderRoute extends MaterialPageRoute<void> {
  _DeepLinkPlaceholderRoute(RouteSettings settings)
      : super(settings: settings, builder: (_) => const SizedBox.shrink()) {
    // Pop immediately if this route is the top route on first build.
    // (Handled here instead of overriding build, which Route doesn't expose.)
  }
}

/// Pops a leftover placeholder route once it becomes the current route again
/// (e.g. after the watch player is closed), or on first build if it is already
/// on top.
class _DeepLinkPlaceholderObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is _DeepLinkPlaceholderRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isCurrent && route.navigator != null && route.navigator!.canPop()) {
          route.navigator!.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute is _DeepLinkPlaceholderRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousRoute.isCurrent &&
            previousRoute.navigator != null &&
            previousRoute.navigator!.canPop()) {
          previousRoute.navigator!.pop();
        }
      });
    }
  }
}