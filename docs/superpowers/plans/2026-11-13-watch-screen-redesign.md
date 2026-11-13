# Watch Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the watch screen with a cinematic TV layout (full-width video with fading overlay controls, compact info bar, horizontal channel strip, Related/Guide tabs) while keeping all existing features working.

**Architecture:** Single-file rewrite of `WatchScreen.build`'s body, reusing the existing providers and the `PlayerStatusOverlay`/`_EpgGuideTab` already in place. Overlay controls fade via a `Timer`-driven `controlsVisible` flag (already in `PlayerSession`); keyboard shortcuts extend the existing `Focus` handler. No new data sources.

**Tech Stack:** Flutter, Material 3, `media_kit_video`, Riverpod.

**Spec:** `docs/superpowers/specs/2026-11-13-watch-screen-redesign-design.md`

## Global Constraints

- `flutter analyze` and `flutter test` must stay green; `flutter build web` must succeed.
- No changes to `player_provider.dart` playback logic.
- Keep `isWatchScreenOpen` tracking and `_initialChannelId` close behavior.
- Black-and-red theme tokens only; no hard-coded palette colors.
- Gradient background (already applied) stays.

## Review Focus

- Overlay controls must not trap taps when hidden (the video area stays tappable to reveal them).
- Channel strip tap must use `play()` with the queue, not `zapTo`, so prev/next and the URL stay consistent.
- Volume persistence: `_lastVolume` already lives in the notifier; the UI must read `session.volume`.
- Keyboard shortcuts must not fire while a text field or dialog has focus.
- Empty/error states must not leave a blank black rectangle.
- Wide (≥900px) layout must not shrink the video below the cinematic size.

---

### Task 1: Overlay controls widget with fade

**Files:**
- Modify: `lib/screens/watch_screen.dart` (video Stack)

**Interfaces:**
- Consumes: `PlayerSession` (`playing`, `volume`, `muted`, `controlsVisible`), `PlayerNotifier` (`togglePlay`, `setVolume`, `toggleMute`, `zap`).
- Produces: a `Positioned.fill` overlay that shows/hides based on `session.controlsVisible`.

- [ ] **Step 1:** Replace the existing `MaterialVideoControls`/`AdaptiveVideoControls` usage with a custom overlay `Stack` child: a transparent full-area `GestureDetector` that calls `notifier.showControls()` on tap, plus a `FadeTransition`/`AnimatedOpacity` control bar (play/pause, prev/next, volume slider + mute, quality, fullscreen) that only renders when `session.controlsVisible`. Auto-hide after `AppConfig.playerControlsHideAfter` while playing (reuse `_restartHideTimer` via `notifier.showControls()`).
- [ ] **Step 2:** Keep `visibleOnMount: false` semantics: controls hidden on mount, revealed on first tap.
- [ ] **Step 3:** Run `flutter analyze`.
- [ ] **Step 4:** Run `flutter build web` to confirm the video widget still compiles.

---

### Task 2: Info bar and action row

**Files:**
- Modify: `lib/screens/watch_screen.dart`

- [ ] **Step 1:** Replace the current channel-info `Row` + action `Row` with a compact info bar: logo (48px circle) + name/group/Now/Next on the left, and an action cluster on the right (Save/Share/Reload as icon buttons with tooltips; labels visible only when width ≥ 600).
- [ ] **Step 2:** Use `AppTheme.accent` for the favorite icon, `AppTheme.textSecondary` for metadata; ensure `contrast` ≥ 4.5 (already covered by theme tests).
- [ ] **Step 3:** Run `flutter analyze`.

---

### Task 3: Horizontal channel strip

**Files:**
- Modify: `lib/screens/watch_screen.dart`

- [ ] **Step 1:** Add a horizontal `ListView` (height 72) below the info bar showing `session.queue` as cards (logo + name). Highlight the current channel with an `AppTheme.accent` border.
- [ ] **Step 2:** On tap, call `notifier.play(channel, session.queue, index)` (queue-aware) and `_refreshRelated()`.
- [ ] **Step 3:** Hide the strip when `session.queue.length < 2`.
- [ ] **Step 4:** Run `flutter analyze`.

---

### Task 4: Related/Guide tabs and empty states

**Files:**
- Modify: `lib/screens/watch_screen.dart`

- [ ] **Step 1:** Keep the `TabBar`/`TabBarView` (Related | Guide) but restyle the tab icons to use `AppTheme.accent` for the selected state.
- [ ] **Step 2:** Related empty state: icon + "No related channels" + "Try another category" hint.
- [ ] **Step 3:** Guide empty state: icon + message + an `OutlinedButton` "Open Settings" that pushes `SettingsScreen` on mobile / shows it in a dialog on wide screens.
- [ ] **Step 4:** Run `flutter analyze`.

---

### Task 5: Keyboard shortcuts

**Files:**
- Modify: `lib/screens/watch_screen.dart`

- [ ] **Step 1:** Extend the existing `Focus.onKeyEvent` handler: Space = play/pause (existing), M = mute (existing), ArrowLeft/ArrowRight = prev/next channel, F = fullscreen. Guard with `ModalRoute.of(context)?.isCurrent == true`.
- [ ] **Step 2:** Run `flutter analyze`.

---

### Task 6: Wide-layout decision

**Files:**
- Modify: `lib/screens/watch_screen.dart`

- [ ] **Step 1:** Remove the previous `wide ? Row(Expanded video, Expanded sidebar)` split; use the single cinematic column at all widths (video full-width, info bar, strip, tabs below). The tabs' content area scrolls internally.
- [ ] **Step 2:** Run `flutter analyze` and `flutter build web`.

---

### Task 7: Verification

- [ ] **Step 1:** Run `flutter analyze` (expect no issues).
- [ ] **Step 2:** Run `flutter test` (expect all pass).
- [ ] **Step 3:** Run `flutter build web` (expect success).
- [ ] **Step 4:** Serve `build/web` on a new port, open the watch screen on mobile-width and desktop-width viewports, screenshot playing/buffering/error/guide states, and confirm layout matches the spec.
- [ ] **Step 5:** Report results and any anomalies to the user.

---

## Self-Review

Spec coverage: layout (Task 1-3, 6), info bar (Task 2), channel strip (Task 3), tabs/empty states (Task 4), keyboard (Task 5), functional wiring (Tasks 1-3), verification (Task 7). All spec sections mapped. Type names (`zap`, `play`, `setVolume`, `toggleMute`, `showControls`) match existing `PlayerNotifier`. No new types introduced. Proportion: plan is shorter than the spec's detail; bodies left to builder as intended.
