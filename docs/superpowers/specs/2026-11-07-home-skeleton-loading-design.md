# Home screen skeleton loading — design

## Intent and why

The home screen's channel list and grid should feel smooth while content is
loading. Today the first load shows a centred spinner and every channel logo
shows its own small spinner while scrolling, which feels busy and janky. A
skeleton layout that mirrors the real content makes loading feel calm and
keeps the UI structurally stable.

## Goals

- Show a skeleton that matches the current view (grid or list) while the
  playlist is loading, instead of the centred spinner.
- Show shimmering logo placeholders at the exact logo size for cards and
  tiles whose images are still loading while the user scrolls.
- No new dependencies; keep the implementation small and reusable.

## Non-goals

- Pagination or infinite scroll. All channels are already loaded in memory.
- Changing the playlist fetching, filtering, or caching logic.
- Redesigning the channel card/tile layout.

## Anti-goals

- A skeleton whose geometry differs from the real card/tile (causes a jump
  when real content appears).
- Heavy animation that hurts scrolling performance.

## Constraints

- Flutter app, existing Teal/Dark theme (`AppTheme`).
- Card geometry: grid uses `SliverGridDelegateWithMaxCrossAxisExtent`
  (max 96, spacing 6, ratio 0.78); list tiles are rows of 40x40 logo plus
  two text lines.
- Default view is grid (`AppSettings.listView = false`).

## Approaches considered

1. **Add the `shimmer` package.** Fast to write, but adds a dependency for a
   small effect and less control over matching the theme.
2. **Hand-rolled shimmer widget.** One `AnimationController` + animated
   gradient `ShaderMask` over plain placeholder shapes. Selected: no new
   dependency, fully controlled, reusable across grid, list and logo
   placeholders.
3. **Static grey placeholders without animation.** Cheapest, but reads as
   broken/empty rather than loading.

## Design

- New `lib/widgets/skeleton.dart`:
  - `Shimmer` — animates a diagonal light sweep across its child; respects
    `MediaQuery.disableAnimations`.
  - `SkeletonBox` — rounded rectangle using theme surface colours.
  - `ChannelGridSkeleton` — same `GridView` delegate, padding and item count
    (enough to fill the screen) as `ChannelGrid`, each item mirroring
    `ChannelCard` (logo area + two text lines).
  - `ChannelListSkeleton` — `ListView.separated` matching `ChannelList`
    padding/separators, each row mirroring `_ChannelTile` (40x40 logo + two
    lines + trailing dots).
- `HomeScreen`: while `playlist` is loading, render the skeleton matching
  `settings.listView` instead of `LoadingState`.
- `ChannelCard._Logo` and `ChannelList._TileLogo`: replace the spinner /
  static letter placeholder with a shimmering skeleton box sized to the logo
  area. The letter fallback remains for images that fail to load.
- Remove the now-unused `showSpinner` path in `ChannelCard` if nothing else
  uses it.

## What is left to the builder

- Exact shimmer colours/timing and placeholder line widths.
- Number of skeleton rows/items (fill the viewport reasonably).
- Widget test coverage for the skeleton appearance during loading.
