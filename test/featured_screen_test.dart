import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/epg.dart';
import 'package:livetv/providers/featured_providers.dart';
import 'package:livetv/screens/featured_screen.dart';

void main() {
  testWidgets('lists featured programmes and filters by kind', (tester) async {
    final now = DateTime.now();
    final item = FeaturedProgramme(
      programme: Programme(
        channelId: 'c1',
        title: 'Big Movie',
        start: now.add(const Duration(hours: 1)),
        stop: now.add(const Duration(hours: 3)),
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
      ProviderScope(
        overrides: [
          featuredProgramsProvider.overrideWithValue([item]),
        ],
        child: const MaterialApp(home: FeaturedScreen()),
      ),
    );

    expect(find.text('Big Movie'), findsOneWidget);

    await tester.tap(find.text('Sports'));
    await tester.pump();

    expect(find.text('Big Movie'), findsNothing);
    expect(
      find.text('No featured programmes right now.'),
      findsOneWidget,
    );
  });
}
