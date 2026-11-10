import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/screens/deep_link_watch_screen.dart';

void main() {
  test('parses hash form', () {
    expect(parseWatchDeepLink('#/watch/AnandaTV.bd'), 'AnandaTV.bd');
  });
  test('parses path form', () {
    expect(parseWatchDeepLink('/watch/AsianTV.bd'), 'AsianTV.bd');
  });
  test('parses full uri with fragment', () {
    expect(parseWatchDeepLink('http://localhost:8089/#/watch/AsianTV.bd'),
        'AsianTV.bd');
  });
  test('decodes channel ids', () {
    expect(parseWatchDeepLink('#/watch/AnandaTV.bd%232'), 'AnandaTV.bd#2');
  });
  test('returns null for unrelated paths', () {
    expect(parseWatchDeepLink('/'), isNull);
    expect(parseWatchDeepLink('#/home'), isNull);
  });
}