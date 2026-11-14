import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` used for programme
/// reminders (scheduled local notifications). All calls are no-ops on web.
class ReminderNotifications {
  ReminderNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC if the local zone cannot be resolved.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Requests OS permission to show notifications. Returns true when granted.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Schedules a reminder [lead] before [start], or at [start] when that is
  /// too close. Returns false when nothing was scheduled (on web, or when the
  /// programme has already started); throws if the OS refuses.
  static Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime start,
    Duration lead = const Duration(minutes: 5),
  }) async {
    if (kIsWeb) return false;
    await init();
    final now = DateTime.now();
    final when = start.subtract(lead);
    final scheduled = when.isAfter(now) ? when : start;
    if (!scheduled.isAfter(now)) return false;

    final tzWhen = tz.TZDateTime.from(scheduled, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'programme_reminders',
      'Programme reminders',
      channelDescription: 'Reminders for upcoming TV programmes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id);
  }

  /// Stable id for a programme reminder.
  ///
  /// Must be the same on every launch so a reminder can still be cancelled
  /// after a restart, which rules out [Object.hash] (seeded per run). This is
  /// a 31-bit FNV-1a hash.
  static int idFor(String channelId, DateTime start) {
    var hash = 0x811c9dc5;
    for (final unit in '$channelId|${start.millisecondsSinceEpoch}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
