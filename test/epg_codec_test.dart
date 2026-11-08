import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/epg_codec.dart';
import 'package:livetv/data/models/epg.dart';

void main() {
  test('round-trips categories and flags', () {
    final data = EpgData(
      byChannel: {
        'c1': [
          Programme(
            channelId: 'c1',
            title: 'Movie A',
            start: DateTime(2026, 11, 8, 21),
            stop: DateTime(2026, 11, 8, 23),
            categories: const ['Movie', 'Action'],
            isNew: true,
            isPremiere: true,
          ),
        ],
      },
      fetchedAt: DateTime(2026, 11, 8),
    );

    final decoded = decodeEpg(encodeEpg(data))!;
    final programme = decoded.programmesFor('c1').single;
    expect(programme.categories, ['Movie', 'Action']);
    expect(programme.isNew, isTrue);
    expect(programme.isPremiere, isTrue);
    expect(decoded.hasCategories, isTrue);
  });

  test('decodes an old cache entry without the new fields', () {
    const oldJson = '''
{"v":1,"fetchedAt":"2026-11-08T00:00:00.000","channels":{"c1":[{"t":"Old","s":"2026-11-08T21:00:00.000","e":"2026-11-08T23:00:00.000"}]}}
''';
    final decoded = decodeEpg(oldJson)!;
    final programme = decoded.programmesFor('c1').single;
    expect(programme.categories, isEmpty);
    expect(programme.isNew, isFalse);
    expect(programme.isPremiere, isFalse);
    expect(decoded.hasCategories, isFalse);
  });
}
