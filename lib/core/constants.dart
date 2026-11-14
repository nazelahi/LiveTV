/// Central configuration for the app.
class AppConfig {
  AppConfig._();

  static const String appName = 'LiveTV';
  static const String appVersion = '1.0.1';

  /// The playlist is downloaded on first launch and refreshed automatically.
  static const String playlistUrl =
      'https://raw.githubusercontent.com/saeidrahmanbd/BDIX-IPTV/main/International-Playlist.m3u';

  /// Optional remote config endpoint. If set, the app fetches the current
  /// playlist URL and version from here so an admin site can change them.
  static const String configUrl =
      'https://liveiptvbd.netlify.app/.netlify/functions/config';

  /// Endpoint that publishes the latest app version. Expected to return either
  /// a plain-text version string (e.g. "1.0.1") or a JSON object with an
  /// "appVersion"/"latestVersion"/"version" field. Leave empty to disable the
  /// remote check and rely on the source page instead.
  static const String appUpdateUrl =
      'https://raw.githubusercontent.com/nazelahi/LiveTV/main/version.txt';

  /// GitHub releases API endpoint used to check for a newer app release.
  static const String appReleaseUrl =
      'https://api.github.com/repos/nazelahi/LiveTV/releases/latest';

  // ---------------------------------------------------------------------------
  // Web Android download banner defaults
  // ---------------------------------------------------------------------------

  /// Whether the web Android download banner is shown by default.
  static const bool androidDownloadEnabled = true;

  /// Default title (version is appended as " (vX)" when known).
  static const String androidDownloadTitle = 'Get the Android app';

  /// Default subtitle.
  static const String androidDownloadSubtitle =
      'Download the native app for smoother playback.';

  /// Default button label.
  static const String androidDownloadButton = 'Download';

  /// Default download URL. Empty means "resolve from GitHub releases /
  /// the hardcoded releases page".
  static const String androidDownloadUrl = '';

  static const String epgUrl =
      'https://raw.githubusercontent.com/saeidrahmanbd/BDIX-IPTV/main/epg/epg.xml';

  static const String sourceUrl =
      'https://github.com/saeidrahmanbd/BDIX-IPTV';

  static const String adultGroup = 'Adult';

  /// Public HTTPS proxy used to relay plain http:// streams on the web build.
  /// Empty disables proxying (falls back to the "Open stream" prompt).
  /// The proxy must accept the target URL appended to this base (URL-encoded).
  static const String webStreamProxyBase = 'https://corsproxy.io/?';

  /// A cached playlist older than this is refreshed in the background.
  static const Duration staleAfter = Duration(minutes: 15);

  static const Duration networkTimeout = Duration(seconds: 40);

  /// How long the player controls stay visible while playing.
  static const Duration playerControlsHideAfter = Duration(seconds: 4);

  /// How often the player checks whether the stream is still advancing.
  static const Duration healthCheckInterval = Duration(seconds: 2);

  /// A playing stream whose position has not moved for this long is restarted.
  /// Kept generous: live streams can pause briefly without being dead.
  static const Duration stallTimeout = Duration(seconds: 30);

  /// A stream that stays buffering this long is treated as dead.
  static const Duration bufferTimeout = Duration(seconds: 45);

  /// Long stream errors are truncated to this many characters.
  static const int maxErrorMessageLength = 300;

  // ---------------------------------------------------------------------------
  // Web / desktop layout
  // ---------------------------------------------------------------------------

  /// Minimum viewport width (in logical pixels) at which the desktop 3-pane
  /// shell is used instead of the mobile layout.
  static const double desktopBreakpoint = 1024;

  /// Width of the left sidebar in the desktop shell.
  static const double desktopSidebarWidth = 260;

  /// Width of the right player panel in the desktop shell, as a fraction of
  /// the viewport width.
  static const double desktopPlayerPanelFraction = 0.38;

  /// Minimum/maximum width of the right player panel in the desktop shell.
  static const double desktopPlayerPanelMinWidth = 360;
  static const double desktopPlayerPanelMaxWidth = 520;
}
