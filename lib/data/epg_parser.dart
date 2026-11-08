import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml_events.dart';

import 'models/epg.dart';

/// Parses an XMLTV document into an [EpgData] instance.
///
/// Top-level and dependency-light so it can run inside [compute].
EpgData parseEpg(String content) {
  final byChannel = <String, List<Programme>>{};

  String? channelId;
  DateTime? start;
  DateTime? stop;
  String? title;
  String? description;
  String? icon;
  var categories = <String>[];
  var isNew = false;
  var isPremiere = false;
  bool inProgramme = false;
  String? activeTag;
  final textBuffer = StringBuffer();

  for (final event in parseEvents(content)) {
    if (event is XmlStartElementEvent) {
      if (event.name == 'programme') {
        inProgramme = true;
        channelId = _attr(event, 'channel');
        start = _parseTime(_attr(event, 'start'));
        stop = _parseTime(_attr(event, 'stop'));
        title = null;
        description = null;
        icon = null;
        categories = <String>[];
        isNew = false;
        isPremiere = false;
        activeTag = null;
        textBuffer.clear();
      } else if (inProgramme &&
          (event.name == 'title' ||
              event.name == 'desc' ||
              event.name == 'category')) {
        activeTag = event.name;
        textBuffer.clear();
      } else if (inProgramme && event.name == 'icon') {
        icon ??= _attr(event, 'src');
      } else if (inProgramme && event.name == 'new') {
        isNew = true;
      } else if (inProgramme && event.name == 'premiere') {
        isPremiere = true;
      }
    } else if (event is XmlTextEvent) {
      if (inProgramme && activeTag != null) {
        textBuffer.write(event.value);
      }
    } else if (event is XmlEndElementEvent) {
      if (!inProgramme) continue;
      if (event.name == 'title' && activeTag == 'title') {
        title = textBuffer.toString().trim();
        activeTag = null;
      } else if (event.name == 'desc' && activeTag == 'desc') {
        final trimmed = textBuffer.toString().trim();
        description = trimmed.isEmpty ? null : trimmed;
        activeTag = null;
      } else if (event.name == 'category' && activeTag == 'category') {
        final trimmed = textBuffer.toString().trim();
        if (trimmed.isNotEmpty && !categories.contains(trimmed)) {
          categories.add(trimmed);
        }
        activeTag = null;
      } else if (event.name == 'programme') {
        if (channelId != null &&
            start != null &&
            stop != null &&
            title != null &&
            title.isNotEmpty) {
          final programme = Programme(
            channelId: channelId,
            title: title,
            start: start,
            stop: stop,
            description: description,
            icon: icon,
            categories: categories,
            isNew: isNew,
            isPremiere: isPremiere,
          );
          byChannel
              .putIfAbsent(channelId, () => <Programme>[])
              .add(programme);
        }
        inProgramme = false;
        channelId = null;
        start = null;
        stop = null;
        title = null;
        description = null;
        icon = null;
        categories = <String>[];
        isNew = false;
        isPremiere = false;
        activeTag = null;
        textBuffer.clear();
      }
    }
  }

  for (final list in byChannel.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }

  return EpgData(byChannel: byChannel, fetchedAt: DateTime.now());
}

String? _attr(XmlStartElementEvent event, String name) {
  for (final attr in event.attributes) {
    if (attr.name == name) return attr.value;
  }
  return null;
}

DateTime? _parseTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // First 14 digits: yyyyMMddHHmmss
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 14) return null;

  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  final hour = int.tryParse(digits.substring(8, 10));
  final minute = int.tryParse(digits.substring(10, 12));
  final second = int.tryParse(digits.substring(12, 14));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  // Timezone offset, if present.
  Duration offset = Duration.zero;
  final tzMatch = RegExp(r'([+-])(\d{2}):?(\d{2})').firstMatch(trimmed);
  if (tzMatch != null) {
    final sign = tzMatch.group(1) == '-' ? -1 : 1;
    final hours = int.tryParse(tzMatch.group(2)!) ?? 0;
    final minutes = int.tryParse(tzMatch.group(3)!) ?? 0;
    offset = Duration(hours: hours, minutes: minutes) * sign;
  }

  final wallUtc = DateTime.utc(year, month, day, hour, minute, second);
  final instantUtc = wallUtc.subtract(offset);
  return instantUtc.toLocal();
}

/// Isolate-friendly entry point that decodes the raw bytes and parses them.
/// Keeps the (potentially large) UTF-8 decode off the UI thread.
EpgData parseEpgBytes(Uint8List bytes) {
  return parseEpg(utf8.decode(bytes));
}