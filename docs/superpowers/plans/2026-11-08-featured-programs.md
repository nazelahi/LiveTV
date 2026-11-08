# Smart EPG Discovery & Featured Programs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect upcoming movies, sports, news and notable shows from the existing XMLTV guide and surface them as a hero rail on the Home screen, with a details sheet and a "See all" screen.

**Architecture:** Extend `Programme` with XMLTV category/premiere metadata, add a pure discovery/ranking module that scans a bounded 48-hour window per channel, expose it through a memoized Riverpod provider, then render a horizontal rail plus a full-screen list. The 65 MB guide is never copied or rescanned on every build.

**Tech Stack:** Flutter, Riverpod 2, cached_network_image, existing `EpgData`/`Channel` models, `flutter_test`.

**Spec:** Approved in conversation on 2026-11-08 (Smart EPG Discovery & Featured Programs).

## Global Constraints

- No new package dependencies.
- Never bump `_epgCacheVersion`; older caches without categories must keep working.
- Always exclude `AppConfig.adultGroup` from featured content, regardless of `showAdult`.
- Discovery scans at most `now + 48h`; the rail shows at most 10 cards.
- The rail is hidden while the Home search box has text or multi-select is active.
- No git repository exists; verification steps replace commit steps.
- The app's palette lives in `lib/core/app_theme.dart`; use `AppTheme.accent`, `accentSecondary`, `danger`, `backgroundAlt`, `textPrimary/Secondary/Muted`.

## Review Focus

- A guide whose programmes sit in the past: discovery must return nothing rather than cards for ended shows.
- Programmes with no `<category>`, no description and no icon: classification must fall back to channel group, and the card must render a gradient instead of a network error.
- The same movie airing on five movie channels: only one card, from the highest-scoring channel.
- A news-only playlist: the rail must not fill with hourly bulletins; titles are deduped and generic news scores below movies/sports.
- A channel whose `tvgId` is null: matching must fall back to `channel.id` and must not crash on an empty key.

---

### Task 1: Extend the EPG model, parser and cache codec

**Files:**
- Modify: `lib/data/models/epg.dart`
- Modify: `lib/data/epg_parser.dart`
- Modify: `lib/data/epg_codec.dart`
- Modify: `test/epg_parser_smoke_test.dart`
- Create: `test/epg_codec_test.dart`

**Interfaces:**
- Produces:
  - `Programme.categories: List<String>` (default `const <String>[]`)
  - `Programme.isNew: bool` (default `false`)
  - `Programme.isPremiere: bool` (default `false`)
  - `Programme.isLiveAt(DateTime now): bool`
  - `parseEpg` continues to return `EpgData`
  - `encodeEpg`/`decodeEpg` round-trip the new fields

- [ ] **Step 1: Write failing parser test**

Add to `test/epg_parser_smoke_test.dart`:

```dart
test('parses categories, new and premiere flags', () {
  const xml = '''
<tv>
  <programme start="20261106141600 +0000" stop="20261106155900 +0000" channel="c1">
    <title>Movie A</title>
    <category lang="en">Movie</category>
    <category lang="en">Action</category>
    <new/>
    <premiere/>
  </programme>
</tv>
''';
  final data = parseEpg(xml);
  final programme = data.programmesFor('c1').single;
  expect(programme.categories, ['Movie', 'Action']);
  expect(programme.isNew, isTrue);
  expect(programme.isPremiere, isTrue);
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/epg_parser_smoke_test.dart`
Expected: compile error (`categories` is not defined).

- [ ] **Step 3: Add fields to `Programme` and parse them**

In `lib/data/models/epg.dart` add the three fields and:

```dart
bool isLiveAt(DateTime now) => !start.isAfter(now) && stop.isAfter(now);

bool get isLive => isLiveAt(DateTime.now());
```

In `lib/data/epg_parser.dart`:
- Add locals `List<String> categories`, `bool isNew`, `bool isPremiere`; reset them when a `<programme>` starts.
- On `XmlStartElementEvent` named `category`, set `activeTag = 'category'` and clear the buffer.
- On `XmlEndElementEvent` named `category` with `activeTag == 'category'`, trim the buffer, add it if non-empty and not already present, then clear `activeTag`.
- On start events named `new` set `isNew = true`; named `premiere` set `isPremiere = true`.
- Pass the fields into the `Programme` constructor.

- [ ] **Step 4: Write failing codec test**

Create `test/epg_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/epg_codec.dart';
import 'package:livetv/data/models/epg.dart';

void main() {
  test('round-trips categories and flags', () {
    final data = EpgData(
      byChannel: {
        'c1': [
          Programme(
            channelId: 'c1',
            title: 'Movie A',
            start: DateTime(2026, 11, 8, 21),
            stop: DateTime(2026, 11, 8, 23),
            categories: const ['Movie', 'Action'],
            isNew: true,
            isPremiere: true,
          ),
        ],
      },
      fetchedAt: DateTime(2026, 11, 8),
    );

    final decoded = decodeEpg(encodeEpg(data))!;
    final programme = decoded.programmesFor('c1').single;
    expect(programme.categories, ['Movie', 'Action']);
    expect(programme.isNew, isTrue);
    expect(programme.isPremiere, isTrue);
  });

  test('decodes an old cache entry without the new fields', () {
    const oldJson = '''
{"v":1,"fetchedAt":"2026-11-08T00:00:00.000","channels":{"c1":[{"t":"Old","s":"2026-11-08T21:00:00.000","e":"2026-11-08T23:00:00.000"}]}}
''';
    final decoded = decodeEpg(oldJson)!;
    final programme = decoded.programmesFor('c1').single;
    expect(programme.categories, isEmpty);
    expect(programme.isNew, isFalse);
    expect(programme.isPremiere, isFalse);
  });
}
```

- [ ] **Step 5: Run it and confirm it fails**

Run: `flutter test test/epg_codec_test.dart`
Expected: FAIL because the fields are not encoded.

- [ ] **Step 6: Encode/decode the fields without a version bump**

In `lib/data/epg_codec.dart`, add to each encoded programme:

```dart
if (programme.categories.isNotEmpty) 'c': programme.categories,
if (programme.isNew) 'n': 1,
if (programme.isPremiere) 'p': 1,
```

When decoding, read `c` as `List` of `String`, and `n`/`p` as `1` or `true`.

- [ ] **Step 7: Verify**

Run: `flutter test test/epg_parser_smoke_test.dart test/epg_codec_test.dart`
Expected: all tests pass.

---

### Task 2: Discovery and ranking engine

**Files:**
- Create: `lib/data/featured_programs.dart`
- Create: `test/featured_programs_test.dart`

**Interfaces:**
- Consumes: `EpgData`, `Programme`, `Channel`, `AppConfig.adultGroup`.
- Produces:
  - `enum FeaturedKind { movie, sport, news, show }`
  - `extension FeaturedKindLabel on FeaturedKind { String get label; }`
  - `class FeaturedProgramme { Programme programme; Channel channel; FeaturedKind kind; int score; }`
  - `FeaturedKind? classifyProgramme(Programme programme, Channel channel)`
  - `List<FeaturedProgramme> discoverFeatured({required EpgData epg, required List<Channel> channels, required DateTime now, Duration horizon = const Duration(hours: 48), int limit = 60})`

- [ ] **Step 1: Write the failing classification tests**

Create `test/featured_programs_test.dart` with helpers:

```dart
Channel channel({String id = 'c1', String name = 'Channel', String group = 'General', String? tvgId}) =>
    Channel(id: id, name: name, url: 'http://example.com/$id.m3u8', group: group, tvgId: tvgId);

Programme programme({
  String channelId = 'c1',
  String title = 'Something',
  DateTime? start,
  Duration duration = const Duration(hours: 2),
  List<String> categories = const [],
  String? description,
  String? icon,
  bool isNew = false,
  bool isPremiere = false,
}) {
  final begin = start ?? DateTime(2026, 11, 8, 21);
  return Programme(
    channelId: channelId,
    title: title,
    start: begin,
    stop: begin.add(duration),
    categories: categories,
    description: description,
    icon: icon,
    isNew: isNew,
    isPremiere: isPremiere,
  );
}
```

Tests:

```dart
test('classifies movie by category', () {
  expect(classifyProgramme(programme(categories: const ['Movie']), channel()), FeaturedKind.movie);
});

test('classifies sport by category and sports group', () {
  expect(classifyProgramme(programme(categories: const ['Sport']), channel()), FeaturedKind.sport);
  expect(classifyProgramme(programme(title: 'Team A vs Team B'), channel(group: 'Sports')), FeaturedKind.sport);
});

test('classifies news and shows', () {
  expect(classifyProgramme(programme(categories: const ['News']), channel(group: 'News')), FeaturedKind.news);
  expect(classifyProgramme(programme(categories: const ['Drama']), channel()), FeaturedKind.show);
});

test('rejects shopping and adult content', () {
  expect(classifyProgramme(programme(categories: const ['Shopping']), channel()), isNull);
  expect(classifyProgramme(programme(categories: const ['Movie']), channel(group: 'Adult')), isNull);
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/featured_programs_test.dart`
Expected: compile error (`classifyProgramme` undefined).

- [ ] **Step 3: Implement classification**

Create `lib/data/featured_programs.dart` with:
- Normalization helper: lowercase, strip diacritics (`áàäâãåéèëêíìïîóòöôõúùüûñç` → ASCII), replace non-alphanumerics with spaces, collapse whitespace.
- Category word lists:
  - movie: `movie, film, kino, cinema, pelicula, фильм, кино`
  - sport: `sport, sports, motori, deportes, futbol, football, cricket`
  - news: `news, nachrichten, actualite, stiri, haber, noticias, новости`
  - show: `series, serial, drama, comedy, komedie, entertainment, documentary, documentar, reality, variety, kids, children, animation, animazione, pohadka`
  - excluded: `shopping, teleshopping, religion, religious, adult, erotic, music, muzyka, muzica, dance/groove, rock/pop, no info, weather`
- Group flags by substring on the normalized group.
- Excluded title/description words: `teleshopping`, `shop now`, `adult`, `xxx`, `porn`, `erotic`.
- Sport title keywords: standalone `vs`/` v `, plus `cricket, football, soccer, fifa, uefa, champions league, premier league, la liga, serie a, bundesliga, world cup, ipl, bpl, nba, nfl, formula 1, f1, grand prix, ufc, wwe, boxing, olympic, t20, odi`.
- Precedence: `sport`, then `movie`, then `news`, then `show`.
- Movie by group requires duration >= 60 minutes; explicit movie category does not.
- Return `null` for `AppConfig.adultGroup`, excluded categories, excluded title words, zero/negative duration, or duration > 8 hours.

- [ ] **Step 4: Run classification tests**

Run: `flutter test test/featured_programs_test.dart`
Expected: PASS.

- [ ] **Step 5: Write failing discovery tests**

Add:

```dart
test('uses tvgId before id and ignores channels without a guide', () {
  final epg = EpgData(byChannel: {'epg-1': [programme(channelId: 'epg-1')]}, fetchedAt: DateTime(2026, 11, 8));
  final items = discoverFeatured(
    epg: epg,
    channels: [channel(id: 'internal', tvgId: 'epg-1'), channel(id: 'missing')],
    now: DateTime(2026, 11, 8, 20),
  );
  expect(items.single.channel.id, 'internal');
});

test('only returns programmes in the live/upcoming window', () {
  final now = DateTime(2026, 11, 8, 20);
  final epg = EpgData(byChannel: {
    'c1': [
      programme(start: DateTime(2026, 11, 8, 10), duration: const Duration(hours: 1)), // ended
      programme(start: DateTime(2026, 11, 8, 21)), // in window
      programme(start: DateTime(2026, 11, 20, 21)), // beyond 48h
    ],
  }, fetchedAt: now);
  final items = discoverFeatured(epg: epg, channels: [channel()], now: now);
  expect(items.map((item) => item.programme.start), [DateTime(2026, 11, 8, 21)]);
});

test('dedupes the same title and keeps the higher score', () {
  final start = DateTime(2026, 11, 8, 21);
  final epg = EpgData(byChannel: {
    'c1': [programme(channelId: 'c1', title: 'Big Movie', start: start, categories: const ['Movie'])],
    'c2': [programme(channelId: 'c2', title: 'Big Movie', start: start, categories: const ['Movie'], isPremiere: true)],
  }, fetchedAt: start);
  final items = discoverFeatured(
    epg: epg,
    channels: [channel(id: 'c1', tvgId: 'c1'), channel(id: 'c2', tvgId: 'c2')],
    now: start.subtract(const Duration(hours: 1)),
  );
  expect(items, hasLength(1));
  expect(items.single.channel.id, 'c2');
});

test('respects the limit and sorts by score then start', () {
  final now = DateTime(2026, 11, 8, 20);
  final programmes = [
    programme(title: 'News', start: DateTime(2026, 11, 8, 21), categories: const ['News']),
    programme(title: 'Movie', start: DateTime(2026, 11, 8, 22), categories: const ['Movie']),
  ];
  final items = discoverFeatured(
    epg: EpgData(byChannel: {'c1': programmes}, fetchedAt: now),
    channels: [channel()],
    now: now,
    limit: 1,
  );
  expect(items.single.programme.title, 'Movie');
});
```

- [ ] **Step 6: Run and confirm failure**

Run: `flutter test test/featured_programs_test.dart`
Expected: FAIL (`discoverFeatured` undefined).

- [ ] **Step 7: Implement discovery**

- Build `Map<String, Channel>` from `channel.tvgId ?? channel.id`, skipping empty keys and `AppConfig.adultGroup`; first channel wins.
- For each channel with a guide list, binary-search the first programme whose `start >= now - 6h`, then iterate until `start > now + horizon`; skip programmes whose `stop <= now`.
- Classify and score each programme.
- Score: base movie 50, sport 55, news 22, show 28; +15 when the channel group matches the kind; +10 `isNew`; +12 `isPremiere`; +12 for start hour 18–22; +8 when movie/sport duration >= 90m; +25 for news titles containing `breaking, election, budget, debate, special, summit`; +6 for `live` in title/description; +8 for `final, premiere, special, world cup, champions league, election, breaking`; +2 when the channel name contains `hd`.
- Dedupe by normalized title, keeping the higher score (tie: earlier start).
- Sort by score descending, then start ascending, then title; take `limit`.

- [ ] **Step 8: Verify**

Run: `flutter test test/featured_programs_test.dart`
Expected: all tests pass.

---

### Task 3: Riverpod providers

**Files:**
- Create: `lib/providers/featured_providers.dart`

**Interfaces:**
- Consumes: `epgProvider`, `playlistProvider`, `discoverFeatured`.
- Produces:
  - `featuredClockProvider: StreamProvider<DateTime>` (initial value plus every 10 minutes)
  - `featuredProgramsProvider: Provider<List<FeaturedProgramme>>`

- [ ] **Step 1: Implement the providers**

```dart
final featuredClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 10),
    (_) => DateTime.now(),
  );
});

final featuredProgramsProvider = Provider<List<FeaturedProgramme>>((ref) {
  final epg = ref.watch(epgProvider).valueOrNull;
  final playlist = ref.watch(playlistProvider).valueOrNull;
  if (epg == null || playlist == null) return const <FeaturedProgramme>[];
  final now = ref.watch(featuredClockProvider).valueOrNull ?? DateTime.now();
  return discoverFeatured(epg: epg, channels: playlist.channels, now: now);
});
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/providers/featured_providers.dart`
Expected: no issues.

---

### Task 4: Shared visual pieces and the featured card

**Files:**
- Create: `lib/widgets/featured_visuals.dart`
- Create: `lib/widgets/featured_card.dart`
- Create: `test/featured_card_test.dart`

**Interfaces:**
- Produces:
  - `Color featuredKindColor(FeaturedKind kind)`
  - `IconData featuredKindIcon(FeaturedKind kind)`
  - `String featuredStartLabel(Programme programme, DateTime now)`
  - `String featuredTimeRange(Programme programme)`
  - `class ProgrammeBackdrop` (image → channel logo → gradient)
  - `class FeaturedCard` with `width = 286`, `height = 152`, required `item`, `now`, `onTap`

- [ ] **Step 1: Write the failing card test**

```dart
testWidgets('shows the kind badge, title and fires onTap', (tester) async {
  var tapped = false;
  final item = FeaturedProgramme(
    programme: Programme(
      channelId: 'c1',
      title: 'Big Movie',
      start: DateTime(2026, 11, 8, 21),
      stop: DateTime(2026, 11, 8, 23),
      categories: const ['Movie'],
    ),
    channel: channel(),
    kind: FeaturedKind.movie,
    score: 50,
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FeaturedCard(item: item, now: DateTime(2026, 11, 8, 20), onTap: () => tapped = true),
    ),
  ));
  expect(find.text('Big Movie'), findsOneWidget);
  expect(find.text('MOVIE'), findsOneWidget);
  expect(find.text('in 1h'), findsOneWidget);
  await tester.tap(find.byType(FeaturedCard));
  expect(tapped, isTrue);
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/featured_card_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement visuals and card**

- `FeaturedCard` uses a `Material` + `InkWell` clipped to a 16-radius rounded rectangle.
- Backdrop fills the card; a bottom black gradient (0.85 → transparent) keeps text legible.
- Top-left pill: `LIVE` (danger) when `programme.isLiveAt(now)`, otherwise the kind label uppercased.
- Top-right pill: `featuredStartLabel`.
- Bottom content: title (2 lines, 14.5 w800), then channel logo 14×14 + name + `HH:mm–HH:mm` in 10.5 text.
- `featuredStartLabel`: `LIVE` if live; `in 1m`/`in 25m`/`in 1h` under 2h; `HH:mm` today; `Tomorrow` tomorrow; otherwise the 3-letter weekday.
- `ProgrammeBackdrop` uses `CachedNetworkImage` (`memCacheWidth: 640`) for `programme.icon`, falls back to `channel.logo`, then a kind-coloured gradient with a large translucent category icon. Never render a broken-image glyph.

- [ ] **Step 4: Verify**

Run: `flutter test test/featured_card_test.dart`
Expected: PASS.

---

### Task 5: Details sheet

**Files:**
- Create: `lib/widgets/programme_details_sheet.dart`

**Interfaces:**
- Produces: `Future<void> showProgrammeDetails(BuildContext context, FeaturedProgramme item)`
- Consumes: `ProgrammeBackdrop`, `featuredKindColor`, `featuredStartLabel`, `WatchScreen`, `EpgChannelScreen`.

- [ ] **Step 1: Implement the sheet**

- `showModalBottomSheet`, `isScrollControlled: true`, rounded top, `AppTheme.backgroundAlt`.
- Max height `MediaQuery.sizeOf(context).height * 0.85`, content scrollable.
- 16:9 `ProgrammeBackdrop`, kind pill + `LIVE`/start chip, title, `Today · 21:00–23:00 · 2h`, channel row (logo, name, group), description.
- Buttons: `Watch live` when live, otherwise `Watch channel`; `Channel guide`.
- Watch: close sheet, push `WatchScreen(queue: [item.channel], initialIndex: 0)`.
- Guide: close sheet, push `EpgChannelScreen(channelId: item.channel.tvgId ?? item.channel.id, title: item.channel.name)`.

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/widgets/programme_details_sheet.dart`
Expected: no issues.

---

### Task 6: Featured rail on Home

**Files:**
- Create: `lib/widgets/featured_rail.dart`
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: `epgProvider`, `featuredProgramsProvider`, `FeaturedCard`, `showProgrammeDetails`, `FeaturedScreen`.
- Produces: `class FeaturedRail extends ConsumerStatefulWidget { ValueChanged<FeaturedKind?> onSeeAll; }`

- [ ] **Step 1: Implement the rail**

- State: `FeaturedKind? _filter`, `Timer` refreshing the countdown every minute.
- States:
  - EPG loading with no cached value → compact shimmer/skeleton row (~152 high).
  - EPG error with no cached value → small retry card calling `epgProvider.notifier.download()`.
  - EPG `null` → compact prompt: icon, "Download the TV guide to see tonight's movies, sports and shows", `Download guide` button.
  - EPG present → header + filter chips + horizontal cards.
- Filter chips: `All`, `Movies`, `Sports`, `News`, `Shows`; selected chip uses accent.
- Items: `ref.watch(featuredProgramsProvider)`, filter by `_filter`, drop `stop <= now`, take 10.
- If empty after filtering → `SizedBox.shrink()`.
- Header: "Featured tonight" + `See all` TextButton calling `widget.onSeeAll(_filter)`.
- Card tap → `showProgrammeDetails(context, item)`.
- Horizontal list: `SizedBox(height: 152)` + `ListView.separated`, horizontal padding 10, gap 10.

- [ ] **Step 2: Wire into Home**

In `lib/screens/home_screen.dart`, after the category bar block and before `_SelectionBar`:

```dart
if (state != null && _query.trim().isEmpty && !_selectionMode)
  FeaturedRail(
    onSeeAll: (kind) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeaturedScreen(initialKind: kind),
      ),
    ),
  ),
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: the only missing piece should be `FeaturedScreen` (Task 7), so complete Task 7 before the final analyze.

---

### Task 7: "See all" screen

**Files:**
- Create: `lib/screens/featured_screen.dart`

**Interfaces:**
- Consumes: `featuredProgramsProvider`, `ProgrammeBackdrop`, `showProgrammeDetails`, `FeaturedKind`.
- Produces: `class FeaturedScreen extends ConsumerStatefulWidget { FeaturedKind? initialKind; }`

- [ ] **Step 1: Implement the screen**

- `Scaffold` + `AppBar(title: Text('Featured'))`.
- Filter chips row matching the rail.
- Items filtered by kind, `stop > now`, sorted by start ascending, grouped under `Today`, `Tomorrow`, weekday names.
- Each group: sticky-looking header with a letter-spaced label, then tiles.
- Tile: 112×72 `ProgrammeBackdrop`, kind pill or `LIVE`, title (2 lines), channel name, time range. Tap → `showProgrammeDetails`.
- Empty state: "No featured programmes right now."

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no issues.

---

### Task 8: Full verification and on-device build

**Files:** none.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run the whole test suite**

Run: `flutter test`
Expected: all tests pass (54 existing + new).

- [ ] **Step 3: Build and install**

Run: `flutter run -d 1591662625000E4`
Expected: APK builds, installs and launches on the I2017 device.

- [ ] **Step 4: Manual smoke check**

- Open Home with no guide → prompt card visible.
- Download the guide from the prompt → rail appears with cards.
- Switch the filter chips → rail updates.
- Tap a card → details sheet opens; `Channel guide` and `Watch channel` navigate.
- Type in search or long-press a channel → rail hides.
- Open `See all` → grouped list renders.
