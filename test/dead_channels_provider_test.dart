import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:livetv/data/hive_store.dart';
import 'package:livetv/providers/dead_channels_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dead_channels_test');
    Hive.init(tempDir.path);
    await HiveStore.open();
  });

  setUp(() async {
    await HiveStore.cache.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('persists and restores ids that contain commas', () {
    final notifier = DeadChannelsNotifier();
    notifier.markDead('http://example.com/a,b');
    notifier.markDead('plain-id');

    final restored = DeadChannelsNotifier();
    expect(restored.state, contains('http://example.com/a,b'));
    expect(restored.state, contains('plain-id'));
  });

  test('migrates the legacy comma-joined format', () {
    HiveStore.cache.put('dead_channels', 'first,second');

    final notifier = DeadChannelsNotifier();
    expect(notifier.state, {'first', 'second'});
  });

  test('clear removes the persisted entry', () {
    final notifier = DeadChannelsNotifier();
    notifier.markDead('dead-one');
    notifier.clear();

    expect(HiveStore.cache.get('dead_channels'), isNull);
    expect(DeadChannelsNotifier().state, isEmpty);
  });
}