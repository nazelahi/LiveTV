# Android TV support design

Date: 2026-11-13

## Goal
Add an Android TV (Google TV) target with a dedicated 10-foot UI, while leaving the existing phone UI untouched. Mobile/tablet/web/macOS/iOS paths are unchanged.

## Non-goals
- No Samsung Tizen / LG webOS / Apple TV runtimes.
- No Play Store listing assets or screenshots.
- No changes to mobile home, desktop shell, or watch flow.

## Approach
1. Detect TV at launch via a native method channel (`UiModeManager` / leanback feature). `main()` passes `isTv` into `LiveTvApp`.
2. Android manifest gets `LEANBACK_LAUNCHER` alongside `LAUNCHER`, `android.software.leanback` (required=false), touchscreen (required=false), and a TV banner. Phone launcher behavior stays identical.
3. Splash pushes a new `TvHomeScreen` when `isTv`, otherwise `RootScreen`.
4. `TvHomeScreen`: remote-first, large tiles. Left rail categories (All, Favorites, playlist groups), top bar (name, search, settings, refresh), big channel grid with focus ring. Selecting a channel starts playback and opens existing `PlayerScreen`.
5. Favorites handled as a pseudo-category.

## Files touched
- `android/.../MainActivity.kt` — add `livetv/tv` channel + `isTv()`.
- `android/app/src/main/AndroidManifest.xml` — leanback category + features + banner.
- `android/.../res/drawable/tv_banner.png` (320x180).
- `lib/core/tv.dart` — new detector.
- `lib/main.dart` — detect + pass `isTv`.
- `lib/app.dart` — accept `isTv`, route splash.
- `lib/screens/splash_screen.dart` — `tvMode` param.
- `lib/screens/tv_home_screen.dart` — new TV UI.
- Tile widget (inline in tv_home_screen).

## Risks
- D-pad spatial navigation in 2D grid may need custom focus controller.
- TV soft keyboard availability varies.
- Playback performance on low-end boxes (media_kit already used).

## Verification
- `flutter analyze`, `flutter test`
- `flutter build apk --release`, sideload on Android TV emulator/device.
