import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Orientation presets shared across screens so the app can temporarily
/// enter landscape (fullscreen player) and reliably return to portrait.
const portraitOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

const landscapeOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

Future<void> lockPortrait() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(portraitOrientations);
}

Future<void> lockLandscape() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(landscapeOrientations);
}

Future<void> enterFullscreenUi() async {
  if (kIsWeb) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await lockLandscape();
}

Future<void> exitFullscreenUi() async {
  if (kIsWeb) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await lockPortrait();
}
