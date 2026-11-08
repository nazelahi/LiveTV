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
    );
  }
}
