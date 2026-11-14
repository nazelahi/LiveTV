# Android TV support implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Android TV target with a dedicated 10-foot UI while leaving the phone UI untouched.

**Architecture:** Detect TV at launch via a native method channel, route splash to a new `TvHomeScreen` on TV, and add the required Android TV manifest entries plus a TV banner. Reuse existing providers and `PlayerScreen` for playback.

**Tech Stack:** Flutter/Dart, Kotlin, Android manifest, media_kit (existing).

**Spec:** `docs/superpowers/specs/2026-11-13-android-tv-design.md`

## Global Constraints
- Mobile/tablet/web/macOS/iOS behavior must remain unchanged.
- No new dependencies.
- Keep changes localized to new TV files plus minimal routing/native wiring.
- Android min/target SDK unchanged.

## Review Focus
- TV detection must not false-positive on phones/tablets; fall back to `false` on any platform/error.
- Manifest must keep phone launcher working and not break existing installs.
- `TvHomeScreen` must not lock orientation or reuse portrait-locked `WatchScreen`.
- Focus traversal must move between sidebar, search, and grid with a remote.
- Back button must exit player to `TvHomeScreen`, not leave audio playing.

---

### Task 1: Android TV manifest and native detection

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/sabbir/livetv/MainActivity.kt`
- Create: `android/app/src/main/res/drawable/tv_banner.png` (320x180)

**Interfaces:**
- Produces: method channel `livetv/tv` with method `isTv` returning `Boolean`.

- [ ] **Step 1: Update manifest**
  Add `uses-feature` for leanback (required=false) and touchscreen (required=false); add `android:banner` to application; add `LEANBACK_LAUNCHER` category to the existing MAIN intent-filter.

- [ ] **Step 2: Add native detection**
  In `MainActivity.kt`, register a `MethodChannel("livetv/tv")` in `configureFlutterEngine` handling `isTv` by checking `UiModeManager.currentModeType == UI_MODE_TYPE_TELEVISION` or `PackageManager.FEATURE_LEANBACK`.

- [ ] **Step 3: Add TV banner asset**
  Create a 320x180 PNG banner and place it at `android/app/src/main/res/drawable/tv_banner.png`.

- [ ] **Step 4: Verify build**
  Run: `flutter build apk --debug`
  Expected: build succeeds.

- [ ] **Step 5: Commit**
  `git commit -m "feat(android-tv): manifest and native TV detection"`

---

### Task 2: Dart TV detector

**Files:**
- Create: `lib/core/tv.dart`

**Interfaces:**
- Produces: `TvDetector.detect() -> Future<bool>`.

- [ ] **Step 1: Implement detector**
  Use `MethodChannel('livetv/tv')`, return `false` on web, non-Android, or any error.

- [ ] **Step 2: Verify analyze**
  Run: `flutter analyze`
  Expected: no errors.

- [ ] **Step 3: Commit**
  `git commit -m "feat(tv): add Dart TV detector"`

---

### Task 3: Route splash to TV home

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `lib/screens/splash_screen.dart`

**Interfaces:**
- Consumes: `TvDetector.detect()`
- Produces: `SplashScreen(tvMode: bool)`; `LiveTvApp(isTv: bool)`.

- [ ] **Step 1: Detect in main**
  Call `TvDetector.detect()` after binding init; pass result to `LiveTvApp`.

- [ ] **Step 2: Update LiveTvApp**
  Add `isTv` field; pass `tvMode: isTv` to `SplashScreen` for non-web.

- [ ] **Step 3: Update SplashScreen**
  Add `tvMode` param (default false); on ready push `TvHomeScreen()` when `tvMode`, else `RootScreen()`.

- [ ] **Step 4: Verify analyze/tests**
  Run: `flutter analyze && flutter test`
  Expected: pass.

- [ ] **Step 5: Commit**
  `git commit -m "feat(tv): route splash to TV home on Android TV"`

---

### Task 4: Dedicated TvHomeScreen

**Files:**
- Create: `lib/screens/tv_home_screen.dart`

**Interfaces:**
- Consumes: `playlistProvider`, `favoritesProvider`, `settingsProvider`, `playerProvider`.
- Produces: `TvHomeScreen` widget.

- [ ] **Step 1: Implement TV home**
  Layout: left category rail, top bar (name/search/settings/refresh), large channel grid. Filtering by group + query + adult toggle; Favorites pseudo-category. Selecting a channel calls `playerProvider.notifier.play(...)` then pushes `PlayerScreen`. Use focusable tiles with visible focus border and `Scrollable.ensureVisible`.

- [ ] **Step 2: Verify analyze**
  Run: `flutter analyze`
  Expected: no errors.

- [ ] **Step 3: Commit**
  `git commit -m "feat(tv): add dedicated 10-foot TV home screen"`

---

### Task 5: Final verification

**Files:** none

- [ ] **Step 1: Run tests**
  Run: `flutter test`
  Expected: all pass.

- [ ] **Step 2: Build APK**
  Run: `flutter build apk --release`
  Expected: build succeeds.

- [ ] **Step 3: Commit (if any fixes)**
  `git commit -m "chore(tv): final verification fixes"`
