import 'package:flutter_test/flutter_test.dart';

import 'package:livetv/data/epg_parser.dart';

void main() {
  test('parses xmltv sample', () {
    const xml = '''
<tv>
  <channel id="c1"><display-name>Chan 1</display-name></channel>
  <programme start="20261106141600 +0000" stop="20261106155900 +0000" channel="c1">
    <title lang="en">Show A</title>
    <desc>Desc A</desc>
    <icon src="http://example.com/a.png" />
  </programme>
  <programme start="20261106155900 +0000" stop="20261106180500 +0000" channel="c1">
    <title>Show B</title>
  </programme>
</tv>
''';
    final data = parseEpg(xml);
    expect(data.channelCount, 1);
    expect(data.programmeCount, 2);
    final programmes = data.programmesFor('c1');
    expect(programmes.first.title, 'Show A');
    expect(programmes.first.description, 'Desc A');
    expect(programmes.first.icon, 'http://example.com/a.png');
  });

  test('parses categories, new and premiere flags', () {
    const xml = '''
<tv>
  <programme start="20261106141600 +0000" stop="20261106155900 +0000" channel="c1">
    <title>Movie A</title>
    <category lang="en">Movie</category>
    <category lang="en">Action</category>
    <new/>
    <premiere/>
  </programme>
</tv>
''';
    final data = parseEpg(xml);
    final programme = data.programmesFor('c1').single;
    expect(programme.categories, ['Movie', 'Action']);
    expect(programme.isNew, isTrue);
    expect(programme.isPremiere, isTrue);
  });
}