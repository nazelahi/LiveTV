# Watch Screen Redesign — Design

**Date:** 2026-11-13
**Status:** Draft — pending approval

## Intent

Replace the current watch screen with a cinematic, TV-first layout that keeps
every existing feature working (playback, channel switching, favorites, share,
reload, EPG guide, errors, autoplay-block prompt) while making the video the
focal point and reducing visual clutter. The user chose Option A (cinematic)
from the mockup round.

## Goals

- Video is the largest element on the screen; controls overlay it and fade.
- All existing actions remain reachable in one tap.
- Channel switching stays on-screen (no route push) and keeps the URL in sync.
- Clear empty/error states so the screen is never a blank black rectangle.
- Consistent with the black-and-red theme and the gradient background.

## Non-goals

- No changes to playback logic beyond wiring (player_provider stays as-is).
- No new data sources or network calls.
- No theme changes.
- No changes to the fullscreen PlayerScreen (it keeps its own layout).

## Anti-goals

- Do not hide controls so deeply that a first-time user can't find them.
- Do not add chrome that competes with the video.
- Do not regress keyboard shortcuts or the autoplay-block prompt.

## Constraints

- Flutter + Material 3, existing providers (playerProvider, favoritesProvider,
  epgProvider, playlistProvider).
- Must keep `isWatchScreenOpen` tracking and `_initialChannelId` close behavior.
- Must remain usable on narrow (mobile) and wide (desktop) viewports.
- `flutter analyze` and `flutter test` must stay green.

## Approaches considered

1. **Option A — Cinematic (chosen).** Full-width video with fading overlay
   controls, compact info bar, horizontal channel strip, tabs for Related/Guide.
   Best match for "TV style"; keeps the existing tab structure familiar.
2. **Option B — Set-top box.** Video left, channel list right on all sizes.
   Rejected: too dense on mobile; the cinematic look is what the user picked.
3. **Keep current layout, restyle only.** Rejected: user asked for a full new
   design, not a reskin.

## Decisions (my calls, flagged for review)

- **Channel strip**: horizontal, swipeable row of channel cards (TV-like,
  matches Option A mockup). Vertical list is the fallback if the strip feels
  too cramped — can switch later.
- **Overlay controls**: full set (play/pause, prev/next, volume, quality,
  fullscreen) fading after 4s of inactivity; tap anywhere on the video to
  reveal. Minimal set rejected because hiding skip/volume behind menus hurts
  usability on a TV-style screen.
- **Info bar**: logo + name + group on the left, Now/Next programme inline on
  the right, actions as icon buttons (labels on wide screens).
- **Wide layout (≥900px)**: video on top spanning full width, info bar and
  channel strip below; the existing 3:2 sidebar split is dropped in favor of
  the cinematic single column. Rationale: the sidebar made the video smaller,
  which fights the goal.
- **Empty states**: "No related channels" and "No guide data" get an icon,
  a one-line explanation, and (for guide) a link to Settings.
- **Error state**: keep the inline `PlayerStatusOverlay` (already added) with
  Retry / Next channel.

## Layout spec

```
┌────────────────────────────────────────────┐
│ AppBar: Back | Channel name | ⚠ Reload ♥ ✕│  (error icon only when errored)
├────────────────────────────────────────────┤
│                                            │
│              VIDEO (16:9, full width)       │
│   [overlay controls: ⏮ ⏸ ⏭  vol  Q  ⛶]   │
│                                            │
├────────────────────────────────────────────┤
│ [logo] Name · Group          Now: …        │
│                            Next: …         │
│  [♥ Save] [↗ Share] [↻ Reload]             │
├────────────────────────────────────────────┤
│  ← channel strip (swipe) →                 │
│  [📺 A] [📺 B] [📺 C] [📺 D] …             │
├────────────────────────────────────────────┤
│  Tabs: Related | Guide                     │
│  (Related list / EPG timeline)             │
└────────────────────────────────────────────┘
```

## Functional requirements

- Tap on video toggles overlay controls; they auto-hide after 4s while playing.
- Prev/next channel buttons call `notifier.zap(±1)` (disabled when queue < 2).
- Volume slider + mute button drive `notifier.setVolume`; mute toggles with M.
- Quality button (existing) stays in the overlay.
- Fullscreen button calls `_enterFullscreen`.
- Save toggles favorite; Share copies the absolute channel URL; Reload retries.
- Guide tab starts at the current programme (already implemented).
- Error icon opens the existing error dialog.
- Autoplay-block shows the "Tap to play" button (already implemented).
- Keyboard: Space play/pause, M mute, ←/→ channel, F fullscreen.

## What's left to the builder

- Exact spacing, radii, and animation durations (within Material 3 norms).
- Whether the channel strip uses `ListView` horizontal or a `PageView`.
- Whether to extract a reusable `ChannelStrip` widget or keep it inline.

## Verification

- `flutter analyze`, full test suite, `flutter build web`.
- Manual check on mobile (narrow) and desktop (wide) viewports.
- Screenshots of the watch screen in playing, buffering, error, and guide states.
