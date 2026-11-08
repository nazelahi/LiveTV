import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:livetv/core/app_theme.dart';
import 'package:livetv/data/hive_store.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/playlist_state.dart';
import 'package:livetv/providers/playlist_providers.dart';
import 'package:livetv/screens/home_screen.dart';
import 'package:livetv/widgets/channel_grid.dart';
import 'package:livetv/widgets/skeleton.dart';

class _LoadingPlaylistNotifier extends PlaylistNotifier {
  @override
  Future<PlaylistState> build() => Completer<PlaylistState>().future;
}

class _DataPlaylistNotifier extends PlaylistNotifier {
  @override
  Future<PlaylistState> build() async => PlaylistState(
    channels: const [
      Channel(
        id: 'one',
        name: 'One TV',
        url: 'http://example.com/one.m3u8',
        group: 'News',
      ),
    ],
    groups: const ['News'],
    updatedAt: DateTime.now(),
    fromCache: true,
  );
}

Widget _app(PlaylistNotifier Function() create) {
  return ProviderScope(
    overrides: [playlistProvider.overrideWith(create)],
    child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('livetv_skeleton_test');
    Hive.init(tempDir.path);
    await HiveStore.open();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('home shows the grid skeleton while the playlist loads', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_LoadingPlaylistNotifier.new));
    await tester.pump();

    expect(find.byType(ChannelGridSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('toggling to list swaps in the list skeleton while loading', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_LoadingPlaylistNotifier.new));
    await tester.pump();

    await tester.tap(find.byTooltip('List view'));
    await tester.pump();

    expect(find.byType(ChannelListSkeleton), findsOneWidget);
    expect(find.byType(ChannelGridSkeleton), findsNothing);
  });

  testWidgets('skeleton ticker stops once the playlist arrives', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_DataPlaylistNotifier.new));
    await tester.pump();
    await tester.pump();

    // The settings box is shared by this test file; normalise to grid view if
    // an earlier test left the list view switched on.
    final backToGrid = find.byTooltip('Grid view');
    if (backToGrid.evaluate().isNotEmpty) {
      await tester.tap(backToGrid);
      await tester.pump();
    }

    expect(find.byType(ChannelGridSkeleton), findsNothing);
    expect(find.byType(ChannelGrid), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
