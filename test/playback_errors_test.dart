import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/core/playback_errors.dart';

void main() {
  test('maps a demuxer parse failure to a readable message', () {
    expect(
      friendlyPlaybackError('PipelineStatus::DEMUXER_ERROR_COULD_NOT_PARSE'),
      'This stream uses a format that cannot be played.',
    );
  });

  test('maps a demuxer error to a readable message', () {
    expect(
      friendlyPlaybackError('Could not demux the stream'),
      'This stream uses a format that cannot be played.',
    );
  });

  test('keeps HTTP status messages', () {
    expect(
      friendlyPlaybackError('HTTP error 404'),
      'Channel not found (HTTP 404).',
    );
  });

  test('detects the media-removal race', () {
    expect(
      isMediaRemovalError(
        'The play() request was interrupted because the media was removed '
        'from the document. https://goo.gl/LdLk22',
      ),
      isTrue,
    );
  });

  test('ignores unrelated stream errors', () {
    expect(isMediaRemovalError('tcp: connection refused'), isFalse);
  });
}
