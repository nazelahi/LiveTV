import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'core/notifications.dart';
import 'data/hive_store.dart';

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

  runApp(const ProviderScope(child: LiveTvApp()));
}
