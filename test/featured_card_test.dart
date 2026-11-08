import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/epg.dart';
import 'package:livetv/widgets/featured_card.dart';

void main() {
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
      channel: const Channel(
        id: 'c1',
        name: 'Cinema One',
        url: 'http://example.com/c1.m3u8',
        group: 'Movies',
      ),
      kind: FeaturedKind.movie,
      score: 50,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FeaturedCard(
              item: item,
              now: DateTime(2026, 11, 8, 20),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Big Movie'), findsOneWidget);
    expect(find.text('MOVIE'), findsOneWidget);
    expect(find.text('in 1h'), findsOneWidget);

    await tester.tap(find.byType(FeaturedCard));
    expect(tapped, isTrue);
  });

  testWidgets('marks a live programme', (tester) async {
    final item = FeaturedProgramme(
      programme: Programme(
        channelId: 'c1',
        title: 'Final',
        start: DateTime(2026, 11, 8, 20),
        stop: DateTime(2026, 11, 8, 22),
        categories: const ['Sport'],
      ),
      channel: const Channel(
        id: 'c1',
        name: 'Arena',
        url: 'http://example.com/c1.m3u8',
        group: 'Sports',
      ),
      kind: FeaturedKind.sport,
      score: 55,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FeaturedCard(
              item: item,
              now: DateTime(2026, 11, 8, 20, 30),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('SPORT'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });
}
