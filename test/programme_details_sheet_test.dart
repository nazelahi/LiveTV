import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/epg.dart';
import 'package:livetv/widgets/programme_details_sheet.dart';

void main() {
  testWidgets('shows programme details and both actions', (tester) async {
    final start = DateTime.now().add(const Duration(hours: 2));
    final item = FeaturedProgramme(
      programme: Programme(
        channelId: 'c1',
        title: 'Big Movie',
        start: start,
        stop: start.add(const Duration(hours: 2)),
        description: 'A great film.',
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
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showProgrammeDetails(context, item),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Big Movie'), findsOneWidget);
    expect(find.text('Cinema One'), findsOneWidget);
    expect(find.text('A great film.'), findsOneWidget);
    expect(find.text('Watch channel'), findsOneWidget);
    expect(find.text('Channel guide'), findsOneWidget);
  });
}
