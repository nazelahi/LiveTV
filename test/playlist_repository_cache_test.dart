import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:livetv/data/hive_store.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/playlist_state.dart';
import 'package:livetv/data/playlist_codec.dart';
import 'package:livetv/data/playlist_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('livetv_cache_test');
    Hive.init(tempDir.path);
    await HiveStore.open();
  });

  setUp(() async {
    await HiveStore.cache.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('loads the parsed cache without re-parsing the raw playlist', () {
    const parsed = ParsedPlaylist(
      channels: [
        Channel(
          id: 'cached.one',
          name: 'Cached One',
          url: 'http://example.com/one.m3u8',
          group: 'News',
        ),
      ],
      groups: ['News'],
    );

    HiveStore.cache.put(HiveStore.playlistRawKey, 'not an m3u playlist');
    HiveStore.cache.put(
      HiveStore.playlistParsedKey,
      encodeParsedPlaylist(parsed),
    );

    final repository = PlaylistRepository();
    addTearDown(repository.dispose);

    final state = repository.readCacheSync();

    expect(state, isNotNull);
    expect(state!.channels.single.name, 'Cached One');
    expect(state.groups, ['News']);
  });

  test('falls back to parsing the raw playlist when the parsed cache is missing',
      () {
    HiveStore.cache.put(HiveStore.playlistRawKey, '''
#EXTINF:-1 group-title="News",News One
http://example.com/news.m3u8
''');

    final repository = PlaylistRepository();
    addTearDown(repository.dispose);

    final state = repository.readCacheSync();

    expect(state, isNotNull);
    expect(state!.channels.single.name, 'News One');
  });
}
