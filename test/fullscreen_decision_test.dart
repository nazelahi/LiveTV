import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/core/fullscreen_decision.dart';

void main() {
  test('entering fullscreen does not close the player', () {
    expect(
      shouldExitOnFullscreenChange(isFullscreen: true, alreadyExiting: false),
      isFalse,
    );
  });

  test('leaving fullscreen closes the player', () {
    expect(
      shouldExitOnFullscreenChange(isFullscreen: false, alreadyExiting: false),
      isTrue,
    );
  });

  test('does not close twice while already exiting', () {
    expect(
      shouldExitOnFullscreenChange(isFullscreen: false, alreadyExiting: true),
      isFalse,
    );
  });
}
