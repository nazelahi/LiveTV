import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/featured_programs.dart';
import 'epg_providers.dart';
import 'playlist_providers.dart';

/// Ranked programmes for the featured rail and the "See all" screen.
///
/// Discovery is the expensive part (it walks up to two days of guide data
/// across every channel), so it runs only when the guide or the playlist
/// changes. Widgets drop programmes that have ended on their own one-minute
/// ticker, which keeps the rail current without rescanning the guide.
final featuredProgramsProvider = Provider<List<FeaturedProgramme>>((ref) {
  final epg = ref.watch(epgProvider).valueOrNull;
  final playlist = ref.watch(playlistProvider).valueOrNull;
  if (epg == null || playlist == null) return const <FeaturedProgramme>[];

  final result = discoverFeatured(
    epg: epg,
    channels: playlist.channels,
    now: DateTime.now(),
  );
  // Vary the featured lineup on every launch without discarding the score
  // ranking: only the top pool is shuffled among itself, so the best
  // programmes still lead the rail and the tail stays ranked.
  const poolSize = 20;
  final pool = result.take(poolSize).toList()..shuffle();
  return <FeaturedProgramme>[...pool, ...result.skip(poolSize)];
});
