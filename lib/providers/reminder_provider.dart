import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Sets or cancels the reminder for [programme]. A reminder is only
  /// recorded as set once the notification was actually scheduled.
  Future<ReminderResult> toggle({
    required String channelId,
    required String channelName,
    required Programme programme,
  }) async {
    final key = keyFor(channelId, programme.start);
    final id = ReminderNotifications.idFor(channelId, programme.start);
    if (state.contains(key)) {
      state = {...state}..remove(key);
      _persist();
      try {
        await ReminderNotifications.cancel(id);
      } catch (_) {}
      return ReminderResult.cancelled;
    }

    if (kIsWeb) return ReminderResult.unsupported;
    if (!programme.start.isAfter(DateTime.now())) {
      return ReminderResult.tooLate;
    }
    if (!await ReminderNotifications.requestPermission()) {
      return ReminderResult.denied;
    }
    final bool scheduled;
    try {
      scheduled = await ReminderNotifications.schedule(
        id: id,
        title: 'Starting soon: ${programme.title}',
        body: '$channelName · ${_time(programme.start)}',
        start: programme.start,
      );
    } catch (_) {
      return ReminderResult.failed;
    }
    if (!scheduled) return ReminderResult.tooLate;
    state = {...state, key};
    _persist();
    return ReminderResult.set;
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

enum ReminderResult {
  set,
  cancelled,
  unsupported,
  tooLate,
  denied,
  failed;

  /// What to tell the user, or null when the button state says it all.
  String? get message => switch (this) {
        ReminderResult.set => "Reminder set. We'll notify you before it starts",
        ReminderResult.cancelled => null,
        ReminderResult.unsupported =>
          'Reminders are only available in the mobile and desktop apps',
        ReminderResult.tooLate => 'This programme has already started',
        ReminderResult.denied =>
          'Allow notifications for LiveTV to get reminders',
        ReminderResult.failed => 'Could not schedule the reminder',
      };
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, Set<String>>((ref) {
  return ReminderNotifier();
});