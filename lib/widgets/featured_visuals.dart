import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/featured_programs.dart';
import '../data/models/channel.dart';
import '../data/models/epg.dart';

Color featuredKindColor(FeaturedKind kind) => switch (kind) {
      FeaturedKind.movie => AppTheme.accent,
      FeaturedKind.sport => AppTheme.accentSecondary,
      FeaturedKind.news => const Color(0xFFCB4B16),
      FeaturedKind.show => const Color(0xFF6C71C4),
    };

IconData featuredKindIcon(FeaturedKind kind) => switch (kind) {
      FeaturedKind.movie => Icons.movie_rounded,
      FeaturedKind.sport => Icons.sports_soccer_rounded,
      FeaturedKind.news => Icons.article_rounded,
      FeaturedKind.show => Icons.theaters_rounded,
    };

/// A short label for the top-right of a card: `LIVE`, `in 25m`, `21:00`,
/// `Tomorrow` or `Mon 21:00`.
String featuredStartLabel(Programme programme, DateTime now) {
  if (programme.isLiveAt(now)) return 'LIVE';

  var difference = programme.start.difference(now);
  if (difference.isNegative) difference = Duration.zero;

  if (difference.inMinutes < 120) {
    if (difference.inMinutes < 1) return 'in 1m';
    if (difference.inMinutes < 60) return 'in ${difference.inMinutes}m';
    return 'in ${difference.inHours}h';
  }
  if (_isSameDay(programme.start, now)) return _hhmm(programme.start);
  if (_isSameDay(programme.start, now.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  return '${_weekday(programme.start)} ${_hhmm(programme.start)}';
}

String featuredTimeRange(Programme programme) =>
    '${_hhmm(programme.start)}–${_hhmm(programme.stop)}';

String featuredDuration(Programme programme) {
  final minutes = programme.duration.inMinutes;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String featuredLongDate(Programme programme, DateTime now) {
  if (_isSameDay(programme.start, now)) return 'Today';
  if (_isSameDay(programme.start, now.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  return '${_weekday(programme.start)}, ${programme.start.day} ${_month(programme.start)}';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hhmm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _weekday(DateTime value) => _weekdays[value.weekday - 1];

String _month(DateTime value) => _months[value.month - 1];

/// Programme artwork with a channel-logo and colour-gradient fallback.
class ProgrammeBackdrop extends StatelessWidget {
  const ProgrammeBackdrop({
    super.key,
    required this.programme,
    required this.channel,
    required this.kind,
  });

  final Programme programme;
  final Channel channel;
  final FeaturedKind kind;

  @override
  Widget build(BuildContext context) {
    final poster = programme.icon?.trim();
    if (poster != null && poster.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: poster,
        fit: BoxFit.cover,
        memCacheWidth: 640,
        imageRenderMethodForWeb: kIsWeb
            ? ImageRenderMethodForWeb.HtmlImage
            : ImageRenderMethodForWeb.HtmlImage,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final color = featuredKindColor(kind);
    final logo = channel.logo?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.5),
            AppTheme.backgroundAlt,
            AppTheme.background,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -14,
            bottom: -16,
            child: Icon(
              featuredKindIcon(kind),
              size: 112,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          if (logo != null && logo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                memCacheWidth: 260,
                imageRenderMethodForWeb: kIsWeb
                    ? ImageRenderMethodForWeb.HtmlImage
                    : ImageRenderMethodForWeb.HtmlImage,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => _initial(),
              ),
            )
          else
            Center(child: _initial()),
        ],
      ),
    );
  }

  Widget _initial() {
    final initial =
        channel.name.trim().isEmpty ? '?' : channel.name.trim()[0].toUpperCase();
    return Text(
      initial,
      style: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Filter pill shared by the Home rail and the "See all" screen.
class FeaturedFilterChip extends StatelessWidget {
  const FeaturedFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppTheme.accent : Colors.white70,
        ),
        side: BorderSide(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.6)
              : AppTheme.textMuted.withValues(alpha: 0.4),
        ),
        selectedColor: AppTheme.accent.withValues(alpha: 0.18),
      ),
    );
  }
}

/// `LIVE` or a countdown/time chip shown on cards and in the details sheet.
class FeaturedStatusChip extends StatelessWidget {
  const FeaturedStatusChip({
    super.key,
    required this.label,
    required this.live,
  });

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: live
            ? AppTheme.danger.withValues(alpha: 0.94)
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small `MOVIE` / `SPORT` / `NEWS` / `SHOW` chip.
class FeaturedKindBadge extends StatelessWidget {
  const FeaturedKindBadge({super.key, required this.kind});

  final FeaturedKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: featuredKindColor(kind).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        kind.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 8.5,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}
