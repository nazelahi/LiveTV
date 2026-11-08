import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/epg.dart';
import 'package:livetv/widgets/featured_rail.dart';

FeaturedProgramme _item({
  required String title,
  required FeaturedKind kind,
  required DateTime start,
}) {
  return FeaturedProgramme(
    programme: Programme(
      channelId: 'c1',
      title: title,
      start: start,
      stop: start.add(const Duration(hours: 2)),
      categories: [kind.label],
    ),
    channel: const Channel(
      id: 'c1',
      name: 'Arena',
      url: 'http://example.com/c1.m3u8',
      group: 'General',
    ),
    kind: kind,
    score: 50,
  );
}

void main() {
  testWidgets('shows cards, filter chips and action callbacks', (tester) async {
    final now = DateTime(2026, 11, 8, 20);
    FeaturedProgramme? tapped;
    FeaturedKind? filtered;
    var seeAllCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturedRailContent(
            items: [
              _item(
                title: 'Big Movie',
                kind: FeaturedKind.movie,
                start: DateTime(2026, 11, 8, 21),
              ),
              _item(
                title: 'The Final',
                kind: FeaturedKind.sport,
                start: DateTime(2026, 11, 8, 22),
              ),
            ],
            selected: null,
            now: now,
            onFilter: (kind) => filtered = kind,
            onSeeAll: (_) => seeAllCalled = true,
            onTap: (item) => tapped = item,
          ),
        ),
      ),
    );

    expect(find.text('Big Movie'), findsOneWidget);
    expect(find.text('The Final'), findsOneWidget);

    await tester.tap(find.text('Movies'));
    expect(filtered, FeaturedKind.movie);

    await tester.tap(find.text('See all'));
    expect(seeAllCalled, isTrue);

    await tester.tap(find.text('Big Movie'));
    expect(tapped?.programme.title, 'Big Movie');
  });

  testWidgets('keeps the filter chips visible when a filter is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturedRailContent(
            items: const [],
            selected: FeaturedKind.news,
            now: DateTime(2026, 11, 8, 20),
            onFilter: (_) {},
            onSeeAll: (_) {},
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('No news highlights right now.'), findsOneWidget);
  });
}
