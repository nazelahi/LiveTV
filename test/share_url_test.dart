import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/core/share_url.dart';

void main() {
  test('includes the site origin so a pasted link opens correctly', () {
    expect(
      buildChannelShareUrl('http://localhost:8081', '/', 'redbull.com'),
      'http://localhost:8081/#/watch/redbull.com',
    );
  });

  test('keeps the deployed sub-path', () {
    expect(
      buildChannelShareUrl('https://example.com', '/app/', 'AsianTV.bd'),
      'https://example.com/app/#/watch/AsianTV.bd',
    );
  });

  test('encodes special characters in the channel id', () {
    expect(
      buildChannelShareUrl('https://example.com', '/', 'AnandaTV.bd#2'),
      'https://example.com/#/watch/AnandaTV.bd%232',
    );
  });

  test('falls back to the root path when the site has no path', () {
    expect(
      buildChannelShareUrl('https://example.com', '', 'redbull.com'),
      'https://example.com/#/watch/redbull.com',
    );
  });
}
