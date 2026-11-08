import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/stream_source.dart';

void main() {
  group('parseStreamSource', () {
    test('keeps a plain URL unchanged and adds no headers', () {
      final source = parseStreamSource('https://example.com/live.m3u8');

      expect(source.url, 'https://example.com/live.m3u8');
      expect(source.headers, isNull);
    });

    test('strips the pipe section and parses headers', () {
      final source = parseStreamSource(
        'http://example.com/live.ts|User-Agent=VLC/3.0&Referer=http://example.com/',
      );

      expect(source.url, 'http://example.com/live.ts');
      expect(source.headers, {
        'User-Agent': 'VLC/3.0',
        'Referer': 'http://example.com/',
      });
    });

    test('keeps equals signs inside header values', () {
      final source = parseStreamSource('http://x/y.m3u8|Cookie=a=b=c');

      expect(source.url, 'http://x/y.m3u8');
      expect(source.headers, {'Cookie': 'a=b=c'});
    });

    test('ignores empty or malformed header parts', () {
      final source = parseStreamSource('http://x/y.m3u8|&Bad&Good=1&=');

      expect(source.url, 'http://x/y.m3u8');
      expect(source.headers, {'Good': '1'});
    });

    test('treats a trailing pipe as no headers', () {
      final source = parseStreamSource('http://x/y.m3u8|');

      expect(source.url, 'http://x/y.m3u8');
      expect(source.headers, isNull);
    });
  });
}
