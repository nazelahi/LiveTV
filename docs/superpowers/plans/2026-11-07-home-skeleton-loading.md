# Home Screen Skeleton Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home screen's centred loading spinner and per-logo spinners with shimmering skeleton placeholders that match the grid and list layouts.

**Architecture:** Add a small, dependency-free skeleton module (`Shimmer`, `SkeletonBox`, `ShimmerBox`) and two layout skeletons that mirror the existing `ChannelGrid`/`ChannelList` geometry. Wire the skeletons into `HomeScreen`'s loading branch and into the logo placeholders of `ChannelCard`/`ChannelList`.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), `cached_network_image`, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-11-07-home-skeleton-loading-design.md`

## Global Constraints

- Do not add any new package to `pubspec.yaml`; the shimmer is hand-rolled.
- This project is **not** a git repository. There are no commit steps; finish each task with `flutter analyze` and the named tests instead.
- Match the existing code style: 2-space indent, single quotes, `const` where possible, `AppTheme` colours rather than hard-coded palette values.
- Default home view is grid (`AppSettings.listView == false`).
- Grid geometry to mirror: `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 96, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.78)` and padding `EdgeInsets.fromLTRB(8, 4, 8, 80)`.
- List geometry to mirror: `ListView.separated` with padding `EdgeInsets.fromLTRB(10, 6, 10, 80)`, separator height `6`, tile padding `EdgeInsets.symmetric(horizontal: 10, vertical: 8)`, logo `40x40`, tile radius `12`.

## Review Focus

- **Large playlists and fast scrolling:** only skeleton boxes for visible cards exist, and each animated placeholder must dispose its `AnimationController`; a leak or rebuild storm would show up as jank.
- **Reduced-motion accessibility setting:** `MediaQuery.disableAnimations == true` must remove the moving sweep but keep the skeleton shapes visible.
- **Toggling grid/list during the initial load:** the skeleton must switch to match the newly selected view immediately.
- **Logos that fail to load:** the error path must still show the existing letter fallback, never a permanent shimmer.
- **Small screens and large text scale:** skeleton item geometry must match the real cards so nothing overflows or jumps when real content replaces it.

---

### Task 1: Shimmer and skeleton primitives

**Files:**
- Create: `lib/widgets/skeleton.dart`
- Test: `test/skeleton_test.dart`

**Interfaces:**
- Consumes: `AppTheme.surfaceHigh` from `lib/core/app_theme.dart`.
- Produces:
  - `class Shimmer extends StatefulWidget` — `const Shimmer({super.key, required Widget child, Duration duration = const Duration(milliseconds: 1200)})`.
  - `class SkeletonBox extends StatelessWidget` — `const SkeletonBox({super.key, double? width, double? height, BorderRadius? borderRadius})`; renders a `Container` with `AppTheme.surfaceHigh` and radius `6` by default. Give it explicit dimensions or a tight parent; under loose constraints it collapses.

- [ ] **Step 1: Write the failing tests**

Create `test/skeleton_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/app_theme.dart';
import 'package:livetv/widgets/skeleton.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('SkeletonBox uses the theme surface colour and requested size',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const SkeletonBox(width: 40, height: 12)),
    );

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;

    expect(decoration.color, AppTheme.surfaceHigh);
    expect(tester.getSize(find.byType(SkeletonBox)), const Size(40, 12));
  });

  testWidgets('Shimmer masks its child when animation is enabled',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const Shimmer(child: SkeletonBox(width: 40, height: 12))),
    );

    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('Shimmer skips the sweep when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Shimmer(child: SkeletonBox(width: 40, height: 12)),
        disableAnimations: true,
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });

  testWidgets('Shimmer stops its controller when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Shimmer(child: SkeletonBox(width: 40, height: 12)),
        disableAnimations: true,
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/skeleton_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:livetv/widgets/skeleton.dart'` / `Shimmer` undefined.

- [ ] **Step 3: Implement `lib/widgets/skeleton.dart`**

Use this implementation (the gradient transform is the non-obvious part):

```dart
import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Sweeps a soft highlight across [child]. One controller per instance; the
/// child is passed through unchanged when the OS asks for reduced motion.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.16),
                Colors.transparent,
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradientTransform(
                _controller.value * 2 - 1,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// A plain rounded placeholder shape. Wrap a group of these in one [Shimmer]
/// so they sweep together.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
  }
}

```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/skeleton_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/widgets/skeleton.dart test/skeleton_test.dart`
Expected: No issues found.

---

### Task 2: Grid and list skeleton layouts

**Files:**
- Modify: `lib/widgets/skeleton.dart`
- Test: `test/skeleton_test.dart`

**Interfaces:**
- Consumes: `Shimmer`, `SkeletonBox` from Task 1.
- Produces:
  - `class ChannelGridSkeleton extends StatelessWidget` — `const ChannelGridSkeleton({super.key})`.
  - `class ChannelListSkeleton extends StatelessWidget` — `const ChannelListSkeleton({super.key})`.

- [ ] **Step 1: Add the failing tests**

Append to `test/skeleton_test.dart`:

```dart
  testWidgets('grid skeleton mirrors the channel grid without spinners',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ChannelGridSkeleton(), disableAnimations: true),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('list skeleton mirrors the channel list without spinners',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ChannelListSkeleton(), disableAnimations: true),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/skeleton_test.dart`
Expected: FAIL — `ChannelGridSkeleton` / `ChannelListSkeleton` undefined.

- [ ] **Step 3: Implement the two skeletons**

Append to `lib/widgets/skeleton.dart`:

```dart
/// Loading placeholder for the channel grid. Mirrors [ChannelGrid]'s delegate,
/// padding and default card layout.
class ChannelGridSkeleton extends StatelessWidget {
  const ChannelGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 96,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.78,
        ),
        itemCount: 30,
        itemBuilder: (context, index) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        children: [
          const Expanded(
            child: SizedBox.expand(
              child: SkeletonBox(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const SkeletonBox(width: 44, height: 8),
          const SizedBox(height: 4),
          const SkeletonBox(width: 28, height: 6),
        ],
      ),
    );
  }
}

/// Loading placeholder for the channel list. Mirrors [ChannelList]'s padding,
/// separators and tile layout.
class ChannelListSkeleton extends StatelessWidget {
  const ChannelListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 80),
        itemCount: 12,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 11),
                SizedBox(height: 6),
                SkeletonBox(width: 64, height: 9),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const SkeletonBox(
            width: 22,
            height: 22,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/skeleton_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/widgets/skeleton.dart test/skeleton_test.dart`
Expected: No issues found.

---

### Task 3: Show the matching skeleton while the playlist loads

**Files:**
- Modify: `lib/screens/home_screen.dart:175-181`
- Create: `test/home_skeleton_test.dart`

**Interfaces:**
- Consumes: `ChannelGridSkeleton`, `ChannelListSkeleton` from Task 2; `playlistProvider`, `PlaylistNotifier`, `PlaylistState` from the existing providers.
- Produces: no new public API. `HomeScreen` renders a skeleton in `playlist.when(loading: ...)` instead of `LoadingState`.

- [ ] **Step 1: Write the failing test**

Create `test/home_skeleton_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:livetv/core/app_theme.dart';
import 'package:livetv/data/hive_store.dart';
import 'package:livetv/data/models/playlist_state.dart';
import 'package:livetv/providers/playlist_providers.dart';
import 'package:livetv/screens/home_screen.dart';
import 'package:livetv/widgets/skeleton.dart';

class _LoadingPlaylistNotifier extends PlaylistNotifier {
  @override
  Future<PlaylistState> build() => Completer<PlaylistState>().future;
}

Widget _app() {
  return ProviderScope(
    overrides: [
      playlistProvider.overrideWith(_LoadingPlaylistNotifier.new),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const HomeScreen(),
    ),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('livetv_skeleton_test');
    Hive.init(tempDir.path);
    await HiveStore.open();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('home shows the grid skeleton while the playlist loads',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(ChannelGridSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('toggling to list swaps in the list skeleton while loading',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byTooltip('List view'));
    await tester.pump();

    expect(find.byType(ChannelListSkeleton), findsOneWidget);
    expect(find.byType(ChannelGridSkeleton), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/home_skeleton_test.dart`
Expected: FAIL — no `ChannelGridSkeleton` in the tree (home still shows `LoadingState`).

- [ ] **Step 3: Wire the skeletons into `HomeScreen`**

Add the import next to the other widget imports in `lib/screens/home_screen.dart`:

```dart
import '../widgets/skeleton.dart';
```

Replace the `loading` branch of `playlist.when` (currently `loading: () => const LoadingState(),`) with:

```dart
                loading: () => settings.listView
                    ? const ChannelListSkeleton()
                    : const ChannelGridSkeleton(),
```

Leave the `error` and `data` branches unchanged.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/home_skeleton_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/screens/home_screen.dart test/home_skeleton_test.dart`
Expected: No issues found.

---

### Task 4: Shimmering logo placeholders while scrolling

**Files:**
- Modify: `lib/widgets/channel_card.dart:98-140`
- Modify: `lib/widgets/channel_list.dart:156-178`
- Test: `test/skeleton_test.dart`

**Interfaces:**
- Consumes: `Shimmer`, `SkeletonBox` from Task 1.
- Produces:
  - `class ShimmerBox extends StatelessWidget` — `const ShimmerBox({super.key, double? width, double? height, BorderRadius? borderRadius})`; returns `Shimmer(child: SkeletonBox(...))`.
  - `ChannelCard` and `ChannelList` logo loading placeholders use `ShimmerBox`.

- [ ] **Step 1: Add the failing test for the placeholder component**

Append to `test/skeleton_test.dart`:

```dart
  testWidgets('a logo placeholder is a shimmering skeleton box',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerBox(width: 40, height: 40)),
    );

    expect(tester.getSize(find.byType(ShimmerBox)), const Size(40, 40));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/skeleton_test.dart`
Expected: FAIL — `ShimmerBox` is undefined.

- [ ] **Step 3: Implement `ShimmerBox`**

Append to `lib/widgets/skeleton.dart`:

```dart
/// A single skeleton box with its own shimmer sweep.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SkeletonBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the grid card placeholder**

In `lib/widgets/channel_card.dart`, add the skeleton import:

```dart
import 'skeleton.dart';
```

In `_Logo.build`, change the `placeholder` callback to a shimmer box. The
`SizedBox.expand` is required because the grid logo sits in an `Expanded`
whose width constraint is loose; a bare `SkeletonBox` would collapse to
zero width:

```dart
        placeholder: (context, url) => const SizedBox.expand(
          child: ShimmerBox(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
```

Then remove the `showSpinner` parameter from `_fallback` and the spinner
branch, so `_fallback` always returns the letter container:

```dart
  Widget _fallback() {
    final initial = channel.name.trim().isEmpty
        ? '?'
        : channel.name.trim().substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent.withValues(alpha: 0.75),
        ),
      ),
    );
  }
```

Update the two remaining `_fallback(...)` call sites (`if (!channel.hasLogo) return _fallback();`
and `errorWidget: ... => _fallback()`) to call it with no arguments.

- [ ] **Step 5: Replace the list tile placeholder**

In `lib/widgets/channel_list.dart`, add the skeleton import:

```dart
import 'skeleton.dart';
```

In `_TileLogo.build`, change the `placeholder` callback to:

```dart
                placeholder: (context, url) => const ShimmerBox(),
```

The surrounding `SizedBox(40x40)` supplies tight constraints, so the
`ShimmerBox` fills the logo area. Keep the `errorWidget` pointing at
`_fallback(channel)`.

- [ ] **Step 6: Run checks and verify visually**

Run:
```bash
flutter test test/skeleton_test.dart test/home_skeleton_test.dart test/channel_favorite_test.dart
flutter analyze lib/widgets/skeleton.dart lib/widgets/channel_card.dart lib/widgets/channel_list.dart
```
Expected: all tests pass (7 in `skeleton_test.dart`), analysis clean.

Then run the app (`flutter run`) and confirm:
- first launch shows the grid/list skeleton instead of the centre spinner;
- scrolling into uncached logos shows a shimmering box that fades to the logo;
- breaking one logo URL still falls back to the letter tile.

---

## Notes for the implementer

- Do not wrap the real (non-placeholder) logo in a `Shimmer`; only the loading
  placeholder should pulse.
- The skeleton grid/list is `NeverScrollableScrollPhysics` because it is shown
  only while the first playlist is loading and is replaced immediately after.
- If `flutter analyze` reports `unused_element` for `_fallback`'s old argument,
  finish removing the parameter rather than suppressing the lint.
