import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/widgets/channel_grid.dart';
import 'package:livetv/widgets/channel_list.dart';

const _channel = Channel(
  id: 'one',
  name: 'One TV',
  url: 'http://example.com/one.m3u8',
  group: 'News',
);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('ChannelList forwards a favourite tap with its channel', (
    tester,
  ) async {
    Channel? toggled;

    await tester.pumpWidget(
      _wrap(
        ChannelList(
          channels: const [_channel],
          favorites: const {},
          onRefresh: () async {},
          onTap: (_, _) {},
          onLongPress: (_) {},
          onFavorite: (channel) => toggled = channel,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pump();

    expect(toggled?.id, 'one');
  });

  testWidgets('ChannelGrid forwards a favourite tap with its channel', (
    tester,
  ) async {
    Channel? toggled;

    await tester.pumpWidget(
      _wrap(
        ChannelGrid(
          channels: const [_channel],
          favorites: const {},
          onRefresh: () async {},
          onTap: (_, _) {},
          onLongPress: (_) {},
          onFavorite: (channel) => toggled = channel,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pump();

    expect(toggled?.id, 'one');
  });

  testWidgets('a saved channel shows the remove action', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChannelList(
          channels: const [_channel],
          favorites: const {'one'},
          onRefresh: () async {},
          onTap: (_, _) {},
          onLongPress: (_) {},
          onFavorite: (_) {},
        ),
      ),
    );

    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });

  testWidgets(
    'a channel without a logo shows the letter fallback, not a shimmer',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChannelGrid(
            channels: const [_channel],
            favorites: const {},
            onRefresh: () async {},
            onTap: (_, _) {},
            onLongPress: (_) {},
            onFavorite: (_) {},
          ),
        ),
      );

      expect(find.text('O'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
