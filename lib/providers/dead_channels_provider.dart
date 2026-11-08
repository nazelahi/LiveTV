import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_store.dart';

/// Persists and exposes the set of channel ids that the startup probe (or a
/// playback failure) has marked as broken. The list is cleared on a playlist
/// refresh so fixed streams get a chance to come back.
class DeadChannelsNotifier extends StateNotifier<Set<String>> {
  DeadChannelsNotifier() : super(_read());

  static const String _key = 'dead_channels';

  static Set<String> _read() {
    final raw = HiveStore.cache.get(_key);
    if (raw == null || raw.isEmpty) return <String>{};

    // New format: a JSON array of channel ids. This survives ids that contain
    // commas (stream URLs).
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      // Fall through to the legacy comma-joined format.
    }

    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  void markDead(String id) {
    if (id.isEmpty || state.contains(id)) return;
    state = {...state, id};
    _persist();
  }

  void markDeadAll(Iterable<String> ids) {
    final next = {...state, ...ids.where((id) => id.isNotEmpty)};
    if (next.length == state.length) return;
    state = next;
    _persist();
  }

  void clear() {
    if (state.isEmpty) {
      HiveStore.cache.delete(_key).ignore();
      return;
    }
    state = <String>{};
    HiveStore.cache.delete(_key).ignore();
  }

  void _persist() {
    HiveStore.cache.put(_key, jsonEncode(state.toList())).ignore();
  }
}

final deadChannelsProvider =
    StateNotifierProvider<DeadChannelsNotifier, Set<String>>((ref) {
  return DeadChannelsNotifier();
});