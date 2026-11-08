import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/skip_dead_channels.dart';

void main() {
  const ids = ['a', 'b', 'c', 'd'];
  String idAt(int index) => ids[index];

  test('returns the next channel when it is healthy', () {
    expect(
      nextWorkingIndex(currentIndex: 0, length: 4, failedIds: {}, idAt: idAt),
      1,
    );
  });

  test('skips failed channels', () {
    expect(
      nextWorkingIndex(
        currentIndex: 0,
        length: 4,
        failedIds: {'b'},
        idAt: idAt,
      ),
      2,
    );
  });

  test('wraps around the list', () {
    expect(
      nextWorkingIndex(
        currentIndex: 3,
        length: 4,
        failedIds: {'a'},
        idAt: idAt,
      ),
      1,
    );
  });

  test('returns null when every other channel failed', () {
    expect(
      nextWorkingIndex(
        currentIndex: 0,
        length: 4,
        failedIds: {'b', 'c', 'd'},
        idAt: idAt,
      ),
      isNull,
    );
  });

  test('returns null for a single channel', () {
    expect(
      nextWorkingIndex(
        currentIndex: 0,
        length: 1,
        failedIds: {},
        idAt: (index) => 'a',
      ),
      isNull,
    );
  });
}
