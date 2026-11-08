export 'playback_errors.dart';

/// Compares two dotted version strings (e.g. "1.0.10" vs "1.0.9").
/// Returns a negative number if [a] < [b], zero if equal, positive if [a] > [b].
/// Non-numeric parts are compared lexicographically as a fallback.
int compareVersions(String a, String b) {
  final aParts = a.split('.');
  final bParts = b.split('.');
  final length = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < length; i++) {
    final aRaw = i < aParts.length ? aParts[i] : '0';
    final bRaw = i < bParts.length ? bParts[i] : '0';
    // Strip any pre-release suffix (e.g. "1.0.0-rc1" -> "1.0.0").
    final aNum = int.tryParse(aRaw.split('-').first);
    final bNum = int.tryParse(bRaw.split('-').first);
    if (aNum != null && bNum != null) {
      if (aNum != bNum) return aNum.compareTo(bNum);
    } else {
      final cmp = aRaw.compareTo(bRaw);
      if (cmp != 0) return cmp;
    }
  }
  // Pre-release handling: a version with a pre-release tag is older.
  final aPre = a.contains('-') ? a.split('-').skip(1).join('-') : '';
  final bPre = b.contains('-') ? b.split('-').skip(1).join('-') : '';
  if (aPre.isEmpty && bPre.isNotEmpty) return 1;
  if (aPre.isNotEmpty && bPre.isEmpty) return -1;
  if (aPre != bPre) return aPre.compareTo(bPre);
  return 0;
}

bool isNewerVersion(String remote, String local) =>
    compareVersions(remote, local) > 0;

String timeAgo(DateTime? time) {
  if (time == null) return 'Never';
  final difference = DateTime.now().difference(time);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}

String formatCount(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]},',
      );
}
