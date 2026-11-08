export 'playback_errors.dart';

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
