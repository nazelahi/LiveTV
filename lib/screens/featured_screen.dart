import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/featured_programs.dart';
import '../providers/featured_providers.dart';
import '../widgets/featured_visuals.dart';
import '../widgets/programme_details_sheet.dart';

/// Full schedule of featured programmes, grouped by day.
class FeaturedScreen extends ConsumerStatefulWidget {
  const FeaturedScreen({super.key, this.initialKind});

  final FeaturedKind? initialKind;

  @override
  ConsumerState<FeaturedScreen> createState() => _FeaturedScreenState();
}

class _FeaturedScreenState extends ConsumerState<FeaturedScreen> {
  late FeaturedKind? _filter = widget.initialKind;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = ref
        .watch(featuredProgramsProvider)
        .where((item) => _filter == null || item.kind == _filter)
        .where((item) => item.programme.stop.isAfter(now))
        .toList(growable: false)
      ..sort((a, b) => a.programme.start.compareTo(b.programme.start));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      tooltip: 'Back',
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Live & upcoming highlights',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                FeaturedFilterChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final kind in FeaturedKind.values)
                  FeaturedFilterChip(
                    label: kind.pluralLabel,
                    selected: _filter == kind,
                    onTap: () => setState(() => _filter = kind),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const _EmptyFeatured()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: _groupedItems(items, now),
                  ),
          ),
        ],
      ),
    ),
    );
  }

  List<Widget> _groupedItems(List<FeaturedProgramme> items, DateTime now) {
    final children = <Widget>[];
    String? currentGroup;

    for (final item in items) {
      final group = featuredLongDate(item.programme, now);
      if (group != currentGroup) {
        currentGroup = group;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              group.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }
      children.add(
        _FeaturedListTile(
          item: item,
          now: now,
          onTap: () => showProgrammeDetails(context, item),
        ),
      );
    }

    return children;
  }
}

class _FeaturedListTile extends StatelessWidget {
  const _FeaturedListTile({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final FeaturedProgramme item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final programme = item.programme;
    final live = programme.isLiveAt(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 108,
                    height: 68,
                    child: ProgrammeBackdrop(
                      programme: programme,
                      channel: item.channel,
                      kind: item.kind,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          FeaturedKindBadge(kind: item.kind),
                          const SizedBox(width: 6),
                          if (live)
                            const FeaturedStatusChip(
                              label: 'LIVE',
                              live: true,
                            )
                          else
                            Flexible(
                              child: Text(
                                featuredStartLabel(programme, now),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        programme.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.channel.name}  ·  '
                        '${featuredTimeRange(programme)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeatured extends StatelessWidget {
  const _EmptyFeatured();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 42,
            color: AppTheme.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            'No featured programmes right now.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
