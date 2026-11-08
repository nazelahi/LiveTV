import '../core/constants.dart';
import 'models/channel.dart';
import 'models/epg.dart';

/// The kind of programme a featured card represents.
enum FeaturedKind { movie, sport, news, show }

extension FeaturedKindLabel on FeaturedKind {
  String get label => switch (this) {
        FeaturedKind.movie => 'Movie',
        FeaturedKind.sport => 'Sport',
        FeaturedKind.news => 'News',
        FeaturedKind.show => 'Show',
      };

  String get pluralLabel => switch (this) {
        FeaturedKind.movie => 'Movies',
        FeaturedKind.sport => 'Sports',
        FeaturedKind.news => 'News',
        FeaturedKind.show => 'Shows',
      };
}

/// A programme selected for the featured rail, together with the channel that
/// airs it and the score used to rank it.
class FeaturedProgramme {
  const FeaturedProgramme({
    required this.programme,
    required this.channel,
    required this.kind,
    required this.score,
  });

  final Programme programme;
  final Channel channel;
  final FeaturedKind kind;
  final int score;
}

/// Picks the most notable movies, sports, news and shows that are live or
/// starting within [horizon].
///
/// The guide's per-channel lists are expected to be sorted by start time, which
/// both `parseEpg` and `decodeEpg` guarantee. Only a bounded window is scanned,
/// so this stays cheap even with a 65 MB guide. Strings are normalised once per
/// programme rather than once per category rule.
List<FeaturedProgramme> discoverFeatured({
  required EpgData epg,
  required List<Channel> channels,
  required DateTime now,
  Duration horizon = const Duration(hours: 48),
  int limit = 60,
}) {
  final contexts = <String, _ChannelContext>{};
  for (final channel in channels) {
    if (channel.group == AppConfig.adultGroup) continue;
    final key = (channel.tvgId ?? channel.id).trim();
    if (key.isEmpty) continue;
    contexts.putIfAbsent(key, () => _ChannelContext(channel));
  }

  final windowEnd = now.add(horizon);
  final minStart = now.subtract(const Duration(hours: 6));
  final bestByTitle = <String, FeaturedProgramme>{};

  for (final entry in contexts.entries) {
    final programmes = epg.byChannel[entry.key];
    if (programmes == null || programmes.isEmpty) continue;

    final context = entry.value;
    for (var i = _firstRelevantIndex(programmes, minStart);
        i < programmes.length;
        i++) {
      final programme = programmes[i];
      if (programme.start.isAfter(windowEnd)) break;
      if (!programme.stop.isAfter(now)) continue;

      final title = _normalize(programme.title);
      if (title.isEmpty) continue;

      final categoryText = _normalize(programme.categories.join(' '));
      // A programme on a country channel with no category and no strong title
      // signal cannot be classified reliably; skip it before doing more work.
      if (!context.featuredGroup &&
          categoryText.isEmpty &&
          !_containsAny(title, _sportTitleWords)) {
        continue;
      }

      final kind = _classify(programme, context, title, categoryText);
      if (kind == null) continue;

      final candidate = FeaturedProgramme(
        programme: programme,
        channel: context.channel,
        kind: kind,
        score: _score(programme, context, kind, title),
      );

      final existing = bestByTitle[title];
      if (existing == null ||
          candidate.score > existing.score ||
          (candidate.score == existing.score &&
              candidate.programme.start.isBefore(existing.programme.start))) {
        bestByTitle[title] = candidate;
      }
    }
  }

  final result = bestByTitle.values.toList(growable: false)
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byStart = a.programme.start.compareTo(b.programme.start);
      if (byStart != 0) return byStart;
      return a.programme.title.compareTo(b.programme.title);
    });

  return result.take(limit).toList(growable: false);
}

/// Returns the strongest kind for a programme, or null when it should not be
/// featured.
FeaturedKind? classifyProgramme(Programme programme, Channel channel) {
  if (channel.group == AppConfig.adultGroup) return null;
  if (programme.duration <= Duration.zero) return null;
  if (programme.duration > const Duration(hours: 8)) return null;

  final title = _normalize(programme.title);
  if (title.isEmpty) return null;

  return _classify(
    programme,
    _ChannelContext(channel),
    title,
    _normalize(programme.categories.join(' ')),
  );
}

FeaturedKind? _classify(
  Programme programme,
  _ChannelContext context,
  String title,
  String categoryText,
) {
  if (_containsAny(title, _excludedTitleWords)) return null;

  final categoryTokens =
      categoryText.isEmpty ? const <String>{} : categoryText.split(' ').toSet();
  if (_categoryMatches(categoryTokens, categoryText, _excludedCategories)) {
    return null;
  }

  final isSport = _categoryMatches(categoryTokens, categoryText, _sportCategories) ||
      context.sportGroup ||
      _containsAny(title, _sportTitleWords) ||
      title.contains(' v ');
  if (isSport) return FeaturedKind.sport;

  final isMovie = _categoryMatches(categoryTokens, categoryText, _movieCategories) ||
      (context.movieGroup &&
          programme.duration >= const Duration(minutes: 60));
  if (isMovie) return FeaturedKind.movie;

  final isNews = _categoryMatches(categoryTokens, categoryText, _newsCategories) ||
      context.newsGroup;
  if (isNews) return FeaturedKind.news;

  final isShow = _categoryMatches(categoryTokens, categoryText, _showCategories) ||
      context.showGroup;
  if (isShow) return FeaturedKind.show;

  return null;
}

int _score(
  Programme programme,
  _ChannelContext context,
  FeaturedKind kind,
  String title,
) {
  var score = switch (kind) {
    FeaturedKind.movie => 50,
    FeaturedKind.sport => 55,
    FeaturedKind.news => 22,
    FeaturedKind.show => 28,
  };

  if (context.matches(kind)) score += 15;
  if (programme.isNew) score += 10;
  if (programme.isPremiere) score += 12;
  if (programme.start.hour >= 18 && programme.start.hour < 23) score += 12;
  if ((kind == FeaturedKind.movie || kind == FeaturedKind.sport) &&
      programme.duration >= const Duration(minutes: 90)) {
    score += 8;
  }
  if (kind == FeaturedKind.news &&
      _containsAny(title, _newsSpecialWords)) {
    score += 25;
  }
  if (_containsWord(title, 'live')) score += 6;
  if (_containsAny(title, _importanceWords)) score += 8;
  if (context.hd) score += 2;

  return score;
}

int _firstRelevantIndex(List<Programme> programmes, DateTime minStart) {
  var low = 0;
  var high = programmes.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (programmes[mid].start.isBefore(minStart)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// Channel facts that never change during a scan.
class _ChannelContext {
  _ChannelContext(this.channel)
      : group = _normalize(channel.group),
        name = _normalize(channel.name) {
    movieGroup = _containsGroup(group, const ['movie', 'cinema', 'film']);
    sportGroup = _containsGroup(group, const ['sport']);
    newsGroup = _containsGroup(group, const ['news']);
    showGroup = _containsGroup(
      group,
      const ['kid', 'entertainment', 'documentary', 'series'],
    );
  }

  final Channel channel;
  final String group;
  final String name;

  late final bool movieGroup;
  late final bool sportGroup;
  late final bool newsGroup;
  late final bool showGroup;

  bool get featuredGroup =>
      movieGroup || sportGroup || newsGroup || showGroup;

  bool get hd => name.contains('hd');

  bool matches(FeaturedKind kind) => switch (kind) {
        FeaturedKind.movie => movieGroup,
        FeaturedKind.sport => sportGroup,
        FeaturedKind.news => newsGroup,
        FeaturedKind.show => showGroup,
      };
}

bool _containsGroup(String normalizedGroup, List<String> words) {
  for (final word in words) {
    if (normalizedGroup.contains(word)) return true;
  }
  return false;
}

bool _categoryMatches(
  Set<String> tokens,
  String text,
  List<String> words,
) {
  for (final word in words) {
    if (word.contains(' ')) {
      if (text.contains(word)) return true;
    } else if (tokens.contains(word)) {
      return true;
    }
  }
  return false;
}

bool _containsAny(String haystack, List<String> words) {
  for (final word in words) {
    if (word.contains(' ')) {
      if (haystack.contains(word)) return true;
    } else if (_containsWord(haystack, word)) {
      return true;
    }
  }
  return false;
}

bool _containsWord(String haystack, String word) {
  var index = haystack.indexOf(word);
  while (index >= 0) {
    final before = index == 0 || haystack.codeUnitAt(index - 1) == 32;
    final afterIndex = index + word.length;
    final after =
        afterIndex == haystack.length || haystack.codeUnitAt(afterIndex) == 32;
    if (before && after) return true;
    index = haystack.indexOf(word, index + 1);
  }
  return false;
}

const _movieCategories = ['movie', 'movies', 'film', 'films', 'kino', 'cinema', 'pelicula', 'фильм', 'кино'];
const _sportCategories = ['sport', 'sports', 'sporting', 'motori', 'deportes', 'futbol', 'football', 'cricket'];
const _newsCategories = ['news', 'nachrichten', 'actualite', 'stiri', 'haber', 'noticias', 'новости'];
const _showCategories = [
  'series',
  'serial',
  'drama',
  'comedy',
  'komedie',
  'entertainment',
  'documentary',
  'documentar',
  'reality',
  'variety',
  'kids',
  'children',
  'animation',
  'animazione',
  'pohadka',
];
const _excludedCategories = [
  'shopping',
  'teleshopping',
  'religion',
  'religious',
  'adult',
  'erotic',
  'music',
  'muzyka',
  'muzica',
  'dance',
  'groove',
  'rock',
  'pop',
  'weather',
  'no info',
];

const _excludedTitleWords = [
  'teleshopping',
  'shop now',
  'adult',
  'xxx',
  'porn',
  'erotic',
];

const _sportTitleWords = [
  'vs',
  'cricket',
  'football',
  'soccer',
  'fifa',
  'uefa',
  'champions league',
  'premier league',
  'la liga',
  'serie a',
  'bundesliga',
  'world cup',
  'ipl',
  'bpl',
  'nba',
  'nfl',
  'formula 1',
  'f1',
  'grand prix',
  'ufc',
  'wwe',
  'boxing',
  'olympic',
  't20',
  'odi',
];

const _newsSpecialWords = [
  'breaking',
  'election',
  'budget',
  'debate',
  'special',
  'summit',
  'address',
  'results',
];

const _importanceWords = [
  'final',
  'premiere',
  'special',
  'world cup',
  'champions league',
  'election',
  'breaking',
];

const _latinFold = <int, int>{
  0xE0: 0x61, 0xE1: 0x61, 0xE2: 0x61, 0xE3: 0x61, 0xE4: 0x61, 0xE5: 0x61,
  0xE6: 0x61, 0xE7: 0x63, 0xE8: 0x65, 0xE9: 0x65, 0xEA: 0x65, 0xEB: 0x65,
  0xEC: 0x69, 0xED: 0x69, 0xEE: 0x69, 0xEF: 0x69, 0xF0: 0x64, 0xF1: 0x6E,
  0xF2: 0x6F, 0xF3: 0x6F, 0xF4: 0x6F, 0xF5: 0x6F, 0xF6: 0x6F, 0xF8: 0x6F,
  0xF9: 0x75, 0xFA: 0x75, 0xFB: 0x75, 0xFC: 0x75, 0xFD: 0x79, 0xFF: 0x79,
  0x101: 0x61, 0x103: 0x61, 0x105: 0x61, 0x107: 0x63, 0x10D: 0x63,
  0x10F: 0x64, 0x111: 0x64, 0x113: 0x65, 0x115: 0x65, 0x117: 0x65,
  0x119: 0x65, 0x11B: 0x65, 0x11F: 0x67, 0x121: 0x67, 0x131: 0x69,
  0x133: 0x69, 0x135: 0x69, 0x137: 0x69, 0x13A: 0x6B, 0x13C: 0x6C,
  0x13E: 0x6C, 0x142: 0x6C, 0x144: 0x6E, 0x146: 0x6E, 0x148: 0x6E,
  0x14B: 0x6E, 0x14D: 0x6F, 0x14F: 0x6F, 0x151: 0x6F, 0x153: 0x6F,
  0x155: 0x72, 0x157: 0x72, 0x159: 0x72, 0x15B: 0x73, 0x15D: 0x73,
  0x15F: 0x73, 0x161: 0x73, 0x163: 0x74, 0x165: 0x74, 0x167: 0x74,
  0x169: 0x75, 0x16B: 0x75, 0x16D: 0x75, 0x16F: 0x75, 0x171: 0x75,
  0x173: 0x75, 0x175: 0x79, 0x177: 0x79, 0x17A: 0x7A, 0x17C: 0x7A,
  0x17E: 0x7A, 0x219: 0x73, 0x21B: 0x74, 0x21D: 0x7A,
};

/// Lower-cases, folds common Latin accents and replaces punctuation with
/// single spaces. Non-Latin letters are preserved so Cyrillic, Arabic and
/// Bengali titles still compare correctly.
String _normalize(String value) {
  if (value.isEmpty) return '';

  final lower = value.toLowerCase();
  final codes = <int>[];
  var pendingSpace = false;

  for (var i = 0; i < lower.length; i++) {
    var code = lower.codeUnitAt(i);
    final folded = _latinFold[code];
    if (folded != null) code = folded;

    final isLetter = code >= 0x61 && code <= 0x7A;
    final isDigit = code >= 0x30 && code <= 0x39;
    if (isLetter || isDigit || code >= 0x80) {
      if (pendingSpace && codes.isNotEmpty) codes.add(0x20);
      pendingSpace = false;
      codes.add(code);
    } else {
      pendingSpace = true;
    }
  }

  return String.fromCharCodes(codes);
}
