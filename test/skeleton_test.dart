import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/widgets/channel_grid.dart';
import 'package:livetv/widgets/channel_list.dart';
import 'package:livetv/widgets/skeleton.dart';

Widget _wrap(
  Widget child, {
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: textScaler,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('SkeletonBox uses the theme surface colour and requested size', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SkeletonBox(width: 40, height: 12)));

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;

    expect(decoration.color, Colors.white.withValues(alpha: 0.12));
    expect(tester.getSize(find.byType(SkeletonBox)), const Size(40, 12));
  });

  testWidgets('Shimmer masks its child when animation is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const Shimmer(child: SkeletonBox(width: 40, height: 12))),
    );

    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('Shimmer skips the sweep when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Shimmer(child: SkeletonBox(width: 40, height: 12)),
        disableAnimations: true,
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });

  testWidgets('Shimmer stops its controller when animations are disabled', (
    tester,
  ) async {
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

  testWidgets('grid skeleton mirrors the channel grid without spinners', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ChannelGridSkeleton(), disableAnimations: true),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('list skeleton mirrors the channel list without spinners', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ChannelListSkeleton(), disableAnimations: true),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a logo placeholder is a shimmering skeleton box', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ShimmerBox(width: 40, height: 40)));

    expect(tester.getSize(find.byType(ShimmerBox)), const Size(40, 40));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });

  testWidgets('grid skeleton reserves text space like a two-line card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longName =
        'A Very Long Channel Name That Definitely Wraps To Two Lines';
    const channel = Channel(
      id: 'long',
      name: longName,
      url: 'http://example.com/long.m3u8',
      group: 'News',
    );

    for (final scaler in <TextScaler>[
      TextScaler.noScaling,
      const TextScaler.linear(2),
    ]) {
      await tester.pumpWidget(
        _wrap(
          ChannelGrid(
            channels: const [channel],
            favorites: const {},
            onRefresh: () async {},
            onTap: (_, _) {},
            onLongPress: (_) {},
            onFavorite: (_) {},
          ),
          textScaler: scaler,
          disableAnimations: true,
        ),
      );

      final realName = tester.getSize(find.text(longName));
      final realGroup = tester.getSize(find.text('News'));

      await tester.pumpWidget(
        _wrap(
          const ChannelGridSkeleton(),
          textScaler: scaler,
          disableAnimations: true,
        ),
      );

      final skeletonName = tester.getSize(
        find
            .byWidgetPredicate(
              (widget) => widget is SizedBox && widget.width == 44,
            )
            .first,
      );
      final skeletonGroup = tester.getSize(
        find
            .byWidgetPredicate(
              (widget) => widget is SizedBox && widget.width == 28,
            )
            .first,
      );

      expect(skeletonName.height, moreOrLessEquals(realName.height));
      expect(skeletonGroup.height, moreOrLessEquals(realGroup.height));
    }
  });

  testWidgets('list skeleton rows match real tile height at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = Channel(
      id: 'one',
      name: 'One TV',
      url: 'http://example.com/one.m3u8',
      group: 'News',
    );

    for (final scaler in <TextScaler>[
      TextScaler.noScaling,
      const TextScaler.linear(2),
    ]) {
      await tester.pumpWidget(
        _wrap(
          ChannelList(
            channels: const [channel],
            favorites: const {},
            onRefresh: () async {},
            onTap: (_, _) {},
            onLongPress: (_) {},
            onFavorite: (_) {},
          ),
          textScaler: scaler,
          disableAnimations: true,
        ),
      );

      final realRow = tester.getSize(
        find
            .descendant(
              of: find.byType(ChannelList),
              matching: find.byType(Row),
            )
            .first,
      );

      await tester.pumpWidget(
        _wrap(
          const ChannelListSkeleton(),
          textScaler: scaler,
          disableAnimations: true,
        ),
      );

      final skeletonRow = tester.getSize(
        find
            .descendant(
              of: find.byType(ChannelListSkeleton),
              matching: find.byType(Row),
            )
            .first,
      );

      expect(skeletonRow.height, moreOrLessEquals(realRow.height));
    }
  });

  testWidgets('removing the skeleton stops its ticker', (tester) async {
    await tester.pumpWidget(_wrap(const ChannelGridSkeleton()));
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(_wrap(const SizedBox()));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
