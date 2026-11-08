import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/featured_programs.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/epg.dart';

Channel channel({
  String id = 'c1',
  String name = 'Channel',
  String group = 'General',
  String? tvgId,
}) =>
    Channel(
      id: id,
      name: name,
      url: 'http://example.com/$id.m3u8',
      group: group,
      tvgId: tvgId,
    );

Programme programme({
  String channelId = 'c1',
  String title = 'Something',
  DateTime? start,
  Duration duration = const Duration(hours: 2),
  List<String> categories = const [],
  String? description,
  String? icon,
  bool isNew = false,
  bool isPremiere = false,
}) {
  final begin = start ?? DateTime(2026, 11, 8, 21);
  return Programme(
    channelId: channelId,
    title: title,
    start: begin,
    stop: begin.add(duration),
    categories: categories,
    description: description,
    icon: icon,
    isNew: isNew,
    isPremiere: isPremiere,
  );
}

void main() {
  group('classification', () {
    test('classifies movie by category', () {
      expect(
        classifyProgramme(programme(categories: const ['Movie']), channel()),
        FeaturedKind.movie,
      );
    });

    test('classifies a feature-length programme on a movie group', () {
      expect(
        classifyProgramme(
          programme(duration: const Duration(minutes: 90)),
          channel(group: 'Indian Movies'),
        ),
        FeaturedKind.movie,
      );
      expect(
        classifyProgramme(
          programme(duration: const Duration(minutes: 30)),
          channel(group: 'Indian Movies'),
        ),
        isNull,
      );
    });

    test('classifies sport by category, group and title', () {
      expect(
        classifyProgramme(programme(categories: const ['Sport']), channel()),
        FeaturedKind.sport,
      );
      expect(
        classifyProgramme(programme(), channel(group: 'Sports')),
        FeaturedKind.sport,
      );
      expect(
        classifyProgramme(
          programme(title: 'Team A vs Team B'),
          channel(name: 'Arena Sports'),
        ),
        FeaturedKind.sport,
      );
    });

    test('classifies news and shows', () {
      expect(
        classifyProgramme(programme(categories: const ['News']), channel()),
        FeaturedKind.news,
      );
      expect(
        classifyProgramme(programme(categories: const ['Drama']), channel()),
        FeaturedKind.show,
      );
    });

    test('rejects shopping, music and adult content', () {
      expect(
        classifyProgramme(programme(categories: const ['Shopping']), channel()),
        isNull,
      );
      expect(
        classifyProgramme(programme(categories: const ['Music']), channel()),
        isNull,
      );
      expect(
        classifyProgramme(
          programme(categories: const ['Movie']),
          channel(group: 'Adult'),
        ),
        isNull,
      );
    });
  });

  group('discovery', () {
    test('uses tvgId before id and ignores channels without a guide', () {
      final epg = EpgData(
        byChannel: {
          'epg-1': [
            programme(channelId: 'epg-1', categories: const ['Movie']),
          ],
        },
        fetchedAt: DateTime(2026, 11, 8),
      );
      final items = discoverFeatured(
        epg: epg,
        channels: [
          channel(id: 'internal', tvgId: 'epg-1'),
          channel(id: 'missing'),
        ],
        now: DateTime(2026, 11, 8, 20),
      );
      expect(items, hasLength(1));
      expect(items.single.channel.id, 'internal');
    });

    test('only returns programmes in the live/upcoming window', () {
      final now = DateTime(2026, 11, 8, 20);
      final epg = EpgData(
        byChannel: {
          'c1': [
            programme(
              start: DateTime(2026, 11, 8, 10),
              duration: const Duration(hours: 1),
              categories: const ['Movie'],
            ),
            programme(
              start: DateTime(2026, 11, 8, 21),
              categories: const ['Movie'],
            ),
            programme(
              start: DateTime(2026, 11, 20, 21),
              categories: const ['Movie'],
            ),
          ],
        },
        fetchedAt: now,
      );
      final items = discoverFeatured(
        epg: epg,
        channels: [channel()],
        now: now,
      );
      expect(
        items.map((item) => item.programme.start),
        [DateTime(2026, 11, 8, 21)],
      );
    });

    test('includes a programme that is live right now', () {
      final now = DateTime(2026, 11, 8, 21, 30);
      final epg = EpgData(
        byChannel: {
          'c1': [
            programme(
              start: DateTime(2026, 11, 8, 21),
              categories: const ['Movie'],
            ),
          ],
        },
        fetchedAt: now,
      );
      final items = discoverFeatured(
        epg: epg,
        channels: [channel()],
        now: now,
      );
      expect(items, hasLength(1));
      expect(items.single.programme.isLiveAt(now), isTrue);
    });

    test('dedupes the same title and keeps the higher score', () {
      final start = DateTime(2026, 11, 8, 21);
      final epg = EpgData(
        byChannel: {
          'c1': [
            programme(
              channelId: 'c1',
              title: 'Big Movie',
              start: start,
              categories: const ['Movie'],
            ),
          ],
          'c2': [
            programme(
              channelId: 'c2',
              title: 'Big Movie',
              start: start,
              categories: const ['Movie'],
              isPremiere: true,
            ),
          ],
        },
        fetchedAt: start,
      );
      final items = discoverFeatured(
        epg: epg,
        channels: [
          channel(id: 'c1', tvgId: 'c1'),
          channel(id: 'c2', tvgId: 'c2'),
        ],
        now: start.subtract(const Duration(hours: 1)),
      );
      expect(items, hasLength(1));
      expect(items.single.channel.id, 'c2');
    });

    test('respects the limit and sorts by score then start', () {
      final now = DateTime(2026, 11, 8, 20);
      final programmes = [
        programme(
          title: 'News',
          start: DateTime(2026, 11, 8, 21),
          categories: const ['News'],
        ),
        programme(
          title: 'Movie',
          start: DateTime(2026, 11, 8, 22),
          categories: const ['Movie'],
        ),
      ];
      final items = discoverFeatured(
        epg: EpgData(byChannel: {'c1': programmes}, fetchedAt: now),
        channels: [channel()],
        now: now,
        limit: 1,
      );
      expect(items.single.programme.title, 'Movie');
    });
  });
}
