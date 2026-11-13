# Black-Red Theme — Design

**Date:** 2026-11-13
**Status:** Approved (conversation, 2026-11-13)

## Intent

Replace the app's Solarized dark palette with a black-and-red palette, without
introducing low contrast, clashing hues, or a flash of the old accent.

## Goals

- Near-black backgrounds and neutral light-gray text throughout.
- Red as the single interaction accent (icons, links, selection, progress).
- Every foreground/background pair the app relies on meets WCAG AA (4.5:1 for
  normal text, 3:1 for large text and UI icons).
- Keep the existing layout, spacing, and typography untouched.
- Update the pre-Flutter boot loader so the first paint is already black/red.

## Non-goals

- No theme switcher; Solarized is removed.
- No redesign of components or navigation.
- No changes to playback or data behavior.

## Approaches considered

1. **Swap color constants only.** Rejected: leaves the teal Android banner,
   orange/violet featured tiles, and a red `danger` that merges into the accent.
2. **Add a Solarized / Black-Red switch.** Rejected: needs a persisted setting
   and theme provider for a look the user does not want to keep.
3. **Rework the palette tokens plus a targeted color audit.** Chosen.

## Palette

| Token | Value | Role |
|---|---|---|
| `background` | `#050506` | app background |
| `backgroundAlt` | `#141416` | dialogs, sheets, panels |
| `surface` | `0x1AFFFFFF` | cards, shimmer base |
| `surfaceHigh` | `0x26FFFFFF` | raised cards |
| `accent` | `#F5101F` | icons, links, selection, accent text |
| `accentFill` | `#C62828` | fills carrying white text |
| `accentSecondary` | `#E5484D` | secondary badge/rose text |
| `danger` | `#FF9100` | LIVE badges, errors, ending notices |
| `textPrimary` | `#F2F2F2` | body and titles |
| `textSecondary` | `#B3B3B6` | subtitles, metadata |
| `textMuted` | `#8A8A8F` | timestamps, hints |
| `backgroundGradient` | `#000000 → #120608 → #1A090C → #0A0A0B` | app shell |
| `accentGradient` | `#FF3B30 → #8E1118` | splash/logo accent |

Measured contrast on `#050506`: text 18.2:1, secondary 9.7:1, muted 5.9:1,
accent 4.8:1, secondary accent 5.2:1, danger 9.0:1. Dark `onPrimary` on
`#F5101F` 4.7:1. White on `accentFill` 5.6:1.

## Decisions

- **Two reds.** `accent` is bright because the codebase uses it as foreground
  text/icons on dark; `accentFill` is darker because white text sits on it.
  A single red cannot pass AA in both roles.
- **Badge labels.** Bright kind badges (movie/sport/news/show) and the LIVE chip
  now use `onAccent` (`#200003`) as their label color; white text failed AA on
  the lighter fills.
- **Material scheme.** `ColorScheme.dark` with `primary: accent`,
  `onPrimary: #200003`, `primaryContainer: #7A0E14`,
  `onPrimaryContainer: #FFD9D9`, `secondaryContainer: #3A0A0D`,
  `onSecondaryContainer: #FFD9D9`. Filled buttons are bright red with near-black
  labels; tonal buttons are deep maroon with pale rose labels.
- **Danger stays amber** so LIVE/error states remain distinct from the accent.
- **Featured kinds:** movie = `accent`, sport = `accentSecondary`,
  news = `danger`, show = `#C0848C` (muted mauve, replaces violet).
- **Android banner button** uses `accentFill` with white text; the banner tint
  and icon use `accentSecondary`.
- **Boot media:** `web/index.html` background `#050506`, text `#F2F2F2`,
  spinner `#FF3B30`; `theme-color` and `manifest.json` colors `#050506`.

## Constraints

- All color values live in `lib/core/app_theme.dart` except the boot loader
  (`web/index.html`, `web/manifest.json`) and the featured-kind map.
- Existing widgets must keep using tokens; no widget should hard-code the new
  palette.
- `flutter analyze` and `flutter test` must stay clean.

## Verification

- New `test/theme_contrast_test.dart` computes WCAG contrast for every pair
  above and fails below AA.
- `flutter analyze`, full test suite, `flutter build web`.
- Before/after screenshots of home, watch, and settings in a browser tab.
