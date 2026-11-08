import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/m3u_parser.dart';

void main() {
  group('parseM3u', () {
    test('parses attributes, display names and group order', () {
      const raw = '''
#EXTM3U url-tvg="http://example.com/epg.xml"
#EXTINF:-1 tvg-id="one.bd" tvg-logo="http://example.com/one.png" group-title="Bangladesh" tvg-name="One",One TV
http://example.com/one.m3u8
#EXTINF:-1 group-title="Sports" tvg-name="Two",Two, Live
http://example.com/two.ts
''';

      final parsed = parseM3u(raw);

      expect(parsed.channels, hasLength(2));
      expect(parsed.channels.first.name, 'One TV');
      expect(parsed.channels.first.group, 'Bangladesh');
      expect(parsed.channels.first.logo, 'http://example.com/one.png');
      expect(parsed.channels.first.id, 'one.bd');
      expect(parsed.channels[1].name, 'Two, Live');
      expect(parsed.channels[1].group, 'Sports');
      expect(parsed.channels[1].logo, isNull);
      expect(parsed.groups, ['Bangladesh', 'Sports']);
    });

    test('falls back to the URL for ids and keeps duplicates unique', () {
      const raw = '''
#EXTINF:-1 group-title="News",Alpha
http://example.com/a.m3u8
#EXTINF:-1 tvg-id="same.id" group-title="News",Beta
http://example.com/b.m3u8
#EXTINF:-1 tvg-id="same.id" group-title="News",Gamma
http://example.com/c.m3u8
''';

      final parsed = parseM3u(raw);
      final ids = parsed.channels.map((channel) => channel.id).toList();

      expect(ids.first, 'http://example.com/a.m3u8');
      expect(ids[1], 'same.id');
      expect(ids[2], 'same.id#2');
      expect(ids.toSet(), hasLength(3));
    });

    test('applies EXTGRP to channels without a group title', () {
      const raw = '''
#EXTGRP:Hidden
#EXTINF:-1,No Group
http://example.com/none.m3u8
''';

      final parsed = parseM3u(raw);
      expect(parsed.channels.single.group, 'Hidden');
    });

    test('ignores directives and empty playlists', () {
      final parsed = parseM3u('#EXTM3U\n#EXTVLCOPT:http-user-agent=test\n');
      expect(parsed.channels, isEmpty);
      expect(parsed.groups, isEmpty);
    });
  });
}
