import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications.dart';
import '../data/hive_store.dart';
import '../data/models/epg.dart';

/// Persists which programme reminders the user has enabled.
class ReminderNotifier extends StateNotifier<Set<String>> {
  ReminderNotifier() : super(_load());

  static Set<String> _load() {
    try {
      final raw = HiveStore.settings.get('reminder_keys');
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  void _persist() {
    try {
      HiveStore.settings.put('reminder_keys', jsonEncode(state.toList()));
    } catch (_) {}
  }

  String keyFor(String channelId, DateTime start) =>
      '$channelId|${start.millisecondsSinceEpoch}';

  bool isReminded(String channelId, DateTime start) =>
      state.contains(keyFor(channelId, start));

  Future<void> toggle({
    required String channelId,
    required String channelName,
    required Programme programme,
  }) async {
    final key = keyFor(channelId, programme.start);
    if (state.contains(key)) {
      // Cancel.
      final id = ReminderNotifications.idFor(channelId, programme.start);
      await ReminderNotifications.cancel(id);
      state = {...state}..remove(key);
    } else {
      // Schedule.
      final id = ReminderNotifications.idFor(channelId, programme.start);
      await ReminderNotifications.schedule(
        id: id,
        title: 'Starting soon: ${programme.title}',
        body: '$channelName · ${_time(programme.start)}',
        start: programme.start,
      );
      state = {...state, key};
    }
    _persist();
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, Set<String>>((ref) {
  return ReminderNotifier();
});