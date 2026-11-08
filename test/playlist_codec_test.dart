import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/data/models/channel.dart';
import 'package:livetv/data/models/playlist_state.dart';
import 'package:livetv/data/playlist_codec.dart';

void main() {
  group('playlist codec', () {
    test('round-trips every channel field and keeps group order', () {
      const parsed = ParsedPlaylist(
        channels: [
          Channel(
            id: 'one.bd',
            name: 'One TV',
            url: 'http://example.com/one.m3u8',
            group: 'Bangladesh',
            logo: 'http://example.com/one.png',
            tvgId: 'one.bd',
            country: 'BD',
            language: 'bn',
          ),
          Channel(
            id: 'http://example.com/two.ts',
            name: 'Two, Live',
            url: 'http://example.com/two.ts',
            group: 'Sports',
          ),
        ],
        groups: ['Bangladesh', 'Sports'],
      );

      final decoded = decodeParsedPlaylist(encodeParsedPlaylist(parsed));

      expect(decoded, isNotNull);
      expect(decoded!.groups, ['Bangladesh', 'Sports']);
      expect(decoded.channels, hasLength(2));

      final one = decoded.channels.first;
      expect(one.id, 'one.bd');
      expect(one.name, 'One TV');
      expect(one.url, 'http://example.com/one.m3u8');
      expect(one.group, 'Bangladesh');
      expect(one.logo, 'http://example.com/one.png');
      expect(one.tvgId, 'one.bd');
      expect(one.country, 'BD');
      expect(one.language, 'bn');

      final two = decoded.channels[1];
      expect(two.name, 'Two, Live');
      expect(two.logo, isNull);
      expect(two.tvgId, isNull);
      expect(two.country, isNull);
      expect(two.language, isNull);
    });

    test('returns null for malformed JSON', () {
      expect(decodeParsedPlaylist('not json'), isNull);
    });

    test('returns null for an unexpected shape', () {
      expect(decodeParsedPlaylist('[]'), isNull);
      expect(decodeParsedPlaylist('{"channels": []}'), isNull);
      expect(decodeParsedPlaylist('{"channels": [], "groups": "News"}'), isNull);
    });

    test('returns null for a different cache version', () {
      expect(
        decodeParsedPlaylist(
          '{"v": 999, "channels": [], "groups": []}',
        ),
        isNull,
      );
    });
  });
}
