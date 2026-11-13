/// Whether a `fullscreenchange` event should close the player.
///
/// The browser fires the same event when fullscreen is entered and when it is
/// left, so entering must not be treated as leaving.
bool shouldExitOnFullscreenChange({
  required bool isFullscreen,
  required bool alreadyExiting,
}) {
  return !isFullscreen && !alreadyExiting;
}
