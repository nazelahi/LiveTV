import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/data/models/epg.dart';

Programme _programme(String title, DateTime start, DateTime stop) {
  return Programme(
    channelId: 'test.channel',
    title: title,
    start: start,
    stop: stop,
  );
}

void main() {
  final now = DateTime(2026, 11, 13, 11, 0);

  test('drops programmes that already finished', () {
    final programmes = [
      _programme('Early', DateTime(2026, 11, 13, 5, 44),
          DateTime(2026, 11, 13, 6, 13)),
      _programme('Live', DateTime(2026, 11, 13, 10, 30),
          DateTime(2026, 11, 13, 11, 30)),
      _programme('Next', DateTime(2026, 11, 13, 11, 30),
          DateTime(2026, 11, 13, 12, 0)),
    ];

    expect(
      upcomingProgrammes(programmes, now).map((p) => p.title),
      ['Live', 'Next'],
    );
  });

  test('keeps a programme that is ending right now out of the guide', () {
    final programmes = [
      _programme('Just finished', DateTime(2026, 11, 13, 10, 0),
          DateTime(2026, 11, 13, 11, 0)),
      _programme('Starting', DateTime(2026, 11, 13, 11, 0),
          DateTime(2026, 11, 13, 11, 30)),
    ];

    expect(
      upcomingProgrammes(programmes, now).map((p) => p.title),
      ['Starting'],
    );
  });

  test('returns an empty list when the guide has no current data', () {
    final programmes = [
      _programme('Yesterday', DateTime(2026, 11, 12, 5, 0),
          DateTime(2026, 11, 12, 6, 0)),
    ];

    expect(upcomingProgrammes(programmes, now), isEmpty);
  });
}
