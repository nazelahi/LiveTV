import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livetv/core/stream_probe.dart';

void main() {
  test('probes a non-HLS stream using the clean URL and parsed headers', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://example.com/live.ts');
      expect(request.headers['User-Agent'], 'VLC/3.0.20');
      expect(request.headers['X-Token'], 'abc');
      return http.Response('data', 200, headers: {'content-type': 'video/mp2t'});
    });

    final ok = await probeStream(
      client,
      'http://example.com/live.ts|X-Token=abc',
    );

    expect(ok, isTrue);
  });

  test('probes an HLS stream and detects the playlist marker', () async {
    final client = MockClient((request) async {
      return http.Response(
        '#EXTM3U\n#EXTINF:10,\nseg.ts\n',
        200,
        headers: {'content-type': 'application/vnd.apple.mpegurl'},
      );
    });

    final ok = await probeStream(client, 'http://example.com/live.m3u8');

    expect(ok, isTrue);
  });

  test('returns false on a non-2xx response', () async {
    final client = MockClient((request) async {
      return http.Response('nope', 404);
    });

    final ok = await probeStream(client, 'http://example.com/live.ts');

    expect(ok, isFalse);
  });

  test('returns false when the request throws', () async {
    final client = MockClient((request) async {
      throw Exception('network down');
    });

    final ok = await probeStream(client, 'http://example.com/live.ts');

    expect(ok, isFalse);
  });
}