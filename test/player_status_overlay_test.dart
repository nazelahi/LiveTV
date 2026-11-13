import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/widgets/player_status_overlay.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: child,
    ),
  );
}

void main() {
  testWidgets('shows a connecting state with the channel name', (tester) async {
    await tester.pumpWidget(
      _host(const PlayerStatusOverlay(channelName: 'Ananda TV')),
    );

    expect(find.text('Connecting to Ananda TV…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('shows the error, retry and next-channel actions',
      (tester) async {
    var retried = 0;
    var skipped = 0;

    await tester.pumpWidget(
      _host(
        PlayerStatusOverlay(
          channelName: 'Ananda TV',
          error: 'This stream uses a format that cannot be played.',
          onRetry: () => retried++,
          onNext: () => skipped++,
        ),
      ),
    );

    expect(find.text("Ananda TV isn't responding"), findsOneWidget);
    expect(
      find.text('This stream uses a format that cannot be played.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Next channel'));

    expect(retried, 1);
    expect(skipped, 1);
  });

  testWidgets('omits next channel when there is no queue', (tester) async {
    await tester.pumpWidget(
      _host(
        PlayerStatusOverlay(
          channelName: 'Ananda TV',
          error: 'Playback stalled.',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Next channel'), findsNothing);
  });
}
