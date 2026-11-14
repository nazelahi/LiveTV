import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/hive_store.dart';
import '../data/playlist_repository.dart';
import '../data/models/channel.dart';
import '../data/models/playlist_state.dart';
import 'channel_probe_provider.dart';
import 'dead_channels_provider.dart';

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class AppSettings {
  const AppSettings({
    this.showAdult = false,
    this.autoplay = true,
    this.listView = false,
    this.autoSkipDead = true,
    this.compatibilityMode = false,
  });

  final bool showAdult;
  final bool autoplay;

  /// When true, channels are shown as a compact list instead of a grid.
  final bool listView;

  /// Move to the next working channel when the current stream fails.
  final bool autoSkipDead;

  /// Software decoding and a larger buffer for streams that refuse to play.
  final bool compatibilityMode;

  AppSettings copyWith({
    bool? showAdult,
    bool? autoplay,
    bool? listView,
    bool? autoSkipDead,
    bool? compatibilityMode,
  }) {
    return AppSettings(
      showAdult: showAdult ?? this.showAdult,
      autoplay: autoplay ?? this.autoplay,
      listView: listView ?? this.listView,
      autoSkipDead: autoSkipDead ?? this.autoSkipDead,
      compatibilityMode: compatibilityMode ?? this.compatibilityMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(_read());

  static const String _showAdultKey = 'show_adult';
  static const String _autoplayKey = 'autoplay';
  static const String _listViewKey = 'list_view';
  static const String _autoSkipKey = 'auto_skip_dead';
  static const String _compatibilityKey = 'compatibility_mode';

  static AppSettings _read() {
    final box = HiveStore.settings;
    return AppSettings(
      showAdult: box.get(_showAdultKey) == 'true',
      autoplay: box.get(_autoplayKey) != 'false',
      listView: box.get(_listViewKey) == 'true',
      autoSkipDead: box.get(_autoSkipKey) != 'false',
      compatibilityMode: box.get(_compatibilityKey) == 'true',
    );
  }

  void setShowAdult(bool value) {
    state = state.copyWith(showAdult: value);
    HiveStore.settings.put(_showAdultKey, value.toString()).ignore();
  }

  void setAutoplay(bool value) {
    state = state.copyWith(autoplay: value);
    HiveStore.settings.put(_autoplayKey, value.toString()).ignore();
  }

  void setListView(bool value) {
    state = state.copyWith(listView: value);
    HiveStore.settings.put(_listViewKey, value.toString()).ignore();
  }

  void setAutoSkipDead(bool value) {
    state = state.copyWith(autoSkipDead: value);
    HiveStore.settings.put(_autoSkipKey, value.toString()).ignore();
  }

  void setCompatibilityMode(bool value) {
    state = state.copyWith(compatibilityMode: value);
    HiveStore.settings.put(_compatibilityKey, value.toString()).ignore();
  }

}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

// ---------------------------------------------------------------------------
// Favourites
// ---------------------------------------------------------------------------

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier()
      : super(HiveStore.favorites.keys.whereType<String>().toSet());

  bool isFavorite(String channelId) => state.contains(channelId);

  void toggle(String channelId) {
    final next = {...state};
    if (!next.remove(channelId)) {
      next.add(channelId);
      HiveStore.favorites.put(channelId, '1').ignore();
    } else {
      HiveStore.favorites.delete(channelId).ignore();
    }
    state = next;
  }

  /// Adds multiple channels to favourites at once, used by the home screen's
  /// multi-select mode. Channels that are already saved are left untouched.
  void addAll(Iterable<String> channelIds) {
    final next = {...state};
    var changed = false;
    for (final channelId in channelIds) {
      if (channelId.isEmpty) continue;
      if (next.add(channelId)) {
        HiveStore.favorites.put(channelId, '1').ignore();
        changed = true;
      }
    }
    if (changed) state = next;
  }

  /// Removes multiple channels from favourites at once, used by the undo
  /// action after a bulk add.
  void removeAll(Iterable<String> channelIds) {
    final next = {...state};
    var changed = false;
    for (final channelId in channelIds) {
      if (channelId.isEmpty) continue;
      if (next.remove(channelId)) {
        HiveStore.favorites.delete(channelId).ignore();
        changed = true;
      }
    }
    if (changed) state = next;
  }

  /// Re-keys favourites saved under the old URL-based channel ids (used for
  /// channels without a tvg-id) to the current ids of [channels].
  void migrateLegacyIds(List<Channel> channels) {
    if (state.isEmpty || channels.isEmpty) return;
    final ids = {for (final channel in channels) channel.id};
    final stale = state.where((id) => !ids.contains(id)).toSet();
    if (stale.isEmpty) return;

    final next = {...state};
    var changed = false;
    for (final channel in channels) {
      // The old id was the raw URL line, which now may carry extra
      // #EXTVLCOPT headers after a `|`.
      for (final legacy in {channel.url, channel.streamUrl}) {
        if (!stale.remove(legacy)) continue;
        next.remove(legacy);
        HiveStore.favorites.delete(legacy).ignore();
        if (next.add(channel.id)) {
          HiveStore.favorites.put(channel.id, '1').ignore();
        }
        changed = true;
      }
      if (stale.isEmpty) break;
    }
    if (changed) state = next;
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

// ---------------------------------------------------------------------------
// Playlist
// ---------------------------------------------------------------------------

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final repository = PlaylistRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

class PlaylistNotifier extends AsyncNotifier<PlaylistState> {
  @override
  Future<PlaylistState> build() async {
    final repository = ref.read(playlistRepositoryProvider);
    final playlist = repository.readCacheSync() ?? await repository.fetch();
    // Deferred: a provider may not modify another one while it is building.
    scheduleMicrotask(() => _migrateFavorites(playlist));
    return playlist;
  }

  void _migrateFavorites(PlaylistState playlist) {
    ref.read(favoritesProvider.notifier).migrateLegacyIds(playlist.channels);
  }

  /// Downloads a fresh playlist. Keeps showing the old one if the download
  /// fails, and rethrows so the UI can explain what happened.
  ///
  /// With [force] false the download is skipped when the admin config says
  /// the playlist has not changed since the cached copy.
  Future<void> refresh({bool force = true}) async {
    final previous = state.valueOrNull;
    // A refresh is the retry point for previously broken channels.
    ref.read(deadChannelsProvider.notifier).clear();
    try {
      final fresh = await ref
          .read(playlistRepositoryProvider)
          .fetchIfUpdated(force: force);
      if (fresh != null) {
        _migrateFavorites(fresh);
        state = AsyncData(fresh);
      } else if (previous != null) {
        state = AsyncData(previous);
        // The channel list is unchanged, so the screens will not start a new
        // probe on their own; re-check the channels that were just cleared.
        unawaited(ref
            .read(channelProbeControllerProvider)
            .run(previous.channels, restart: true));
      }
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> clearCache() async {
    await ref.read(playlistRepositoryProvider).clearCache();
    ref.read(deadChannelsProvider.notifier).clear();
  }
}

final playlistProvider =
    AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(PlaylistNotifier.new);

/// The URL the currently loaded playlist was fetched from: the admin-configured
/// URL when one has been downloaded, otherwise the built-in fallback.
final playlistSourceUrlProvider = Provider<String>((ref) {
  ref.watch(playlistProvider);
  final urls = PlaylistRepository.cachedUrls();
  if (urls == null || urls.isEmpty) {
    return AppConfig.playlistUrl;
  }
  if (urls.length == 1) {
    return urls.first;
  }
  return 'Multiple playlists (${urls.length})';
});
