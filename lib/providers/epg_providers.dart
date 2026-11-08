import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/epg_repository.dart';
import '../data/models/epg.dart';

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final repository = EpgRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

/// A cached guide older than this is refreshed in the background.
const Duration _epgStaleAfter = Duration(hours: 12);

class EpgNotifier extends AsyncNotifier<EpgData?> {
  @override
  Future<EpgData?> build() async {
    final repository = ref.read(epgRepositoryProvider);
    final cached = repository.readCacheSync();

    if (cached == null) {
      // Auto-download on first launch (or after the cache was cleared) so the
      // user never has to trigger it manually.
      unawaited(_autoDownload(repository));
      return null;
    }

    // Refresh stale guides in the background without blocking the UI.
    if (DateTime.now().difference(cached.fetchedAt) > _epgStaleAfter) {
      unawaited(_autoRefresh(repository));
    }

    return cached;
  }

  Future<void> _autoDownload(EpgRepository repository) async {
    try {
      final data = await repository.fetch();
      state = AsyncData(data);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _autoRefresh(EpgRepository repository) async {
    try {
      final data = await repository.fetch();
      state = AsyncData(data);
    } catch (_) {
      // Keep the stale guide on failure; the next launch will retry.
    }
  }

  Future<EpgData> download() async {
    state = const AsyncLoading();
    try {
      final data = await ref.read(epgRepositoryProvider).fetch();
      state = AsyncData(data);
      return data;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> clear() async {
    await ref.read(epgRepositoryProvider).clearCache();
    state = const AsyncData(null);
  }
}

final epgProvider =
    AsyncNotifierProvider<EpgNotifier, EpgData?>(EpgNotifier.new);

/// Convenience: whether a guide is currently available.
final epgAvailableProvider = Provider<bool>((ref) {
  return ref.watch(epgProvider).valueOrNull != null;
});