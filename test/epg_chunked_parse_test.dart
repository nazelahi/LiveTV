import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:livetv/data/epg_parser.dart';

void main() {
  test('chunked parse matches full parse', () async {
    const xml = '''
<tv>
  <channel id="c1"><display-name>Chan 1</display-name></channel>
  <programme start="20261106141600 +0000" stop="20261106155900 +0000" channel="c1">
    <title>Show A</title>
  </programme>
  <programme start="20261106155900 +0000" stop="20261106180500 +0000" channel="c1">
    <title>Show B</title>
  </programme>
</tv>
''';
    final bytes = utf8.encode(xml);
    final full = parseEpg(xml);
    final chunked = await parseEpgChunked(Uint8List.fromList(bytes));
    expect(chunked.channelCount, full.channelCount);
    expect(chunked.programmeCount, full.programmeCount);
    expect(chunked.programmesFor('c1').map((p) => p.title).toList(),
        ['Show A', 'Show B']);
  });
}