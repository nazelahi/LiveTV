import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/core/playback_errors.dart';

void main() {
  test('detects the Chrome autoplay rejection', () {
    expect(
      isAutoplayBlockedError(
        "play() failed because the user didn't interact with the "
        'document first. https://goo.gl/xX8pDD',
      ),
      isTrue,
    );
  });

  test('detects the Safari NotAllowedError rejection', () {
    expect(
      isAutoplayBlockedError(
        'NotAllowedError: The request is not allowed by the user agent or '
        'the platform in the current context.',
      ),
      isTrue,
    );
  });

  test('detects a missing user gesture', () {
    expect(
      isAutoplayBlockedError('A user gesture is required to start playback.'),
      isTrue,
    );
  });

  test('ignores the media-removal race seen on channel switches', () {
    expect(
      isAutoplayBlockedError(
        'The play() request was interrupted because the media was removed '
        'from the document.',
      ),
      isFalse,
    );
  });

  test('ignores unrelated stream errors', () {
    expect(
      isAutoplayBlockedError('tcp: connection refused'),
      isFalse,
    );
  });
}
