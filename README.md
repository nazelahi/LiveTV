# LiveTV

A small Flutter IPTV player that loads the
[BDIX-IPTV International playlist](https://github.com/saeidrahmanbd/BDIX-IPTV)
on launch and plays channels inside the app.

## What it does

- **Auto-loads** the playlist from GitHub on first start and caches it, so the
  channel list opens instantly next time and still works offline.
- Refreshes automatically when the cached copy is more than 15 minutes old, and
  offers pull-to-refresh everywhere.
- **3,000+ channels** in the playlist's own categories, with logos, search and a
  favourites list.
- **In-app playback** with `media_kit` (libmpv): HLS (`.m3u8`), raw MPEG-TS
  (`.ts`), DASH (`.mpd`) and `.flv` streams.
- Player controls: play/pause, mute, previous/next channel, reload, copy stream
  URL, favourite, buffering indicator and a readable error screen with retry.
- **Adult section hidden by default.** Enable it in Settings after a
  confirmation.
- Dark UI, landscape player, keeps the screen awake, immersive mode.

## Admin panel

The playlist can be managed at <https://liveiptvbd.netlify.app>. The app reads its
remote config from `/.netlify/functions/config` on that site (see
`AppConfig.configUrl`).

## Requirements

- Flutter 3.47 or newer (Dart 3.13+)
- Android SDK (API 21+) and/or Xcode for iOS

## Run

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`.

Build for the web (hostable on Netlify or any static host):

```bash
flutter build web --release
```

Output is `build/web`. The included `netlify.toml` uses this command and publishes
`build/web`. Netlify's default build image does not include Flutter, so either
enable a Flutter build plugin on the site or build in CI and deploy `build/web`
(e.g. via the Netlify CLI). Plain `http://` streams are blocked by browsers on
an `https://` site, so the web build shows an "Open stream" prompt
for those channels instead of playing them in-page.

## Structure

```text
lib/
  core/                 constants, theme, small helpers
  data/
    models/             Channel, PlaylistState
    m3u_parser.dart     dependency-free EXTINF parser (runs on an isolate)
    playlist_repository.dart  download + Hive cache
    hive_store.dart     box names/accessors
  providers/            Riverpod providers (settings, favourites, playlist)
  screens/              home, favourites, settings, player, root shell
  widgets/              channel card/grid and loading/error/empty states
```

The playlist is cached as raw text in Hive and parsed with `compute()` in a
background isolate. The parser and its tests are pure Dart, so they run without
any platform setup.

## Notes and limitations

- 1,049 of the playlist's stream URLs are plain `http://`. The app allows
  cleartext traffic on Android and iOS so those channels can play. Without the
  exceptions in `AndroidManifest.xml` / `Info.plist`, roughly a third of the
  channels would fail silently.
- The playlist is BDIX-oriented, so many streams may only be reachable from
  networks in Bangladesh. Dead or geo-blocked channels show an error with
  **Retry** and **Next channel** instead of hanging forever.
- The TV guide (EPG) can be downloaded on demand from Settings (about 69 MB).
  It provides now/next info on the watch screen and a full browsable guide.
- This app ships no streams. It only plays the third-party playlist and caches
  its public URL; all channel availability and content remain the playlist
  author's responsibility.

## Tests

```bash
flutter test
flutter analyze
```
