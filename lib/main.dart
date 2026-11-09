import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'core/notifications.dart';
import 'data/hive_store.dart';

/// Optional Sentry DSN. Pass via `--dart-define=SENTRY_DSN=...` at build time.
/// Leave empty to disable crash reporting (e.g. for local dev).
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTheme.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // Initialize storage and media engine up front so the web build can skip the
  // splash screen and render the app shell immediately.
  await Hive.initFlutter();
  await HiveStore.open();
  await ReminderNotifications.init();
  MediaKit.ensureInitialized();

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = kReleaseMode ? 'production' : 'debug';
      },
      appRunner: () => runApp(const ProviderScope(child: LiveTvApp())),
    );
  } else {
    runApp(const ProviderScope(child: LiveTvApp()));
  }
}