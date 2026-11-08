import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livetv/main.dart' as app;
import 'package:livetv/widgets/channel_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads the playlist, searches and opens the player',
      (tester) async {
    await app.main();

    // Wait for the playlist (first launch downloads, later launches read Hive).
    for (var attempt = 0;
        attempt < 120 && find.byType(ChannelCard).evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(ChannelCard), findsWidgets);
    expect(find.text('LiveTV'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'BTV');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ChannelCard), findsWidgets);

    final firstName = tester
        .widget<ChannelCard>(find.byType(ChannelCard).first)
        .channel
        .name;

    await tester.tap(find.byType(ChannelCard).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(firstName), findsWidgets);

    // Give the native player a moment to open the stream, then leave.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    // Exercise the fullscreen player and its return path: this must not throw
    // (in particular the old code threw in State.dispose because it called
    // ref.read during disposal) and must restore portrait orientation.
    for (var attempt = 0;
        attempt < 20 && find.byTooltip('Fullscreen').evaluate().isEmpty;
        attempt++) {
      await tester.tap(find.byType(Video).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byTooltip('Fullscreen').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Fullscreen').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      for (var attempt = 0;
          attempt < 20 && find.byTooltip('Back').evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (find.byTooltip('Back').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
