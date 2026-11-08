import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/featured_programs.dart';
import '../providers/epg_providers.dart';
import '../providers/featured_providers.dart';
import 'featured_card.dart';
import 'featured_visuals.dart';
import 'programme_details_sheet.dart';

/// Home-screen rail of live and upcoming movies, sports, news and shows.
class FeaturedRail extends ConsumerStatefulWidget {
  const FeaturedRail({super.key, required this.onSeeAll});

  final ValueChanged<FeaturedKind?> onSeeAll;

  @override
  ConsumerState<FeaturedRail> createState() => _FeaturedRailState();
}

class _FeaturedRailState extends ConsumerState<FeaturedRail> {
  FeaturedKind? _filter;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epgState = ref.watch(epgProvider);
    final allItems = ref.watch(featuredProgramsProvider);
    final now = DateTime.now();

    return epgState.when(
      loading: () => const _RailNotice(
        text: 'Loading TV guide…',
        busy: true,
      ),
      error: (error, _) => _RailError(
        onRetry: () {
          unawaited(ref.read(epgProvider.notifier).download());
        },
      ),
      data: (epg) {
        if (epg == null) {
          return _GuidePrompt(
            title: "Tonight's highlights",
            message: 'Download the TV guide (65 MB) to see movies, sports and '
                'big shows.',
            buttonLabel: 'Get guide',
            onPressed: () {
              unawaited(ref.read(epgProvider.notifier).download());
            },
          );
        }
        if (!epg.hasCategories) {
          return _GuidePrompt(
            title: 'Refresh the TV guide',
            message: 'Your saved guide is missing programme categories. '
                'Refresh it (65 MB) to unlock smart highlights.',
            buttonLabel: 'Refresh',
            onPressed: () {
              unawaited(ref.read(epgProvider.notifier).download());
            },
          );
        }

        final available = allItems
            .where((item) => item.programme.stop.isAfter(now))
            .toList(growable: false);
        if (available.isEmpty) return const SizedBox.shrink();

        final items = available
            .where((item) => _filter == null || item.kind == _filter)
            .take(10)
            .toList(growable: false);

        return FeaturedRailContent(
          items: items,
          selected: _filter,
          now: now,
          onFilter: (kind) {
            setState(() => _filter = kind);
          },
          onSeeAll: widget.onSeeAll,
          onTap: (item) => showProgrammeDetails(context, item),
        );
      },
    );
  }
}

/// Stateless rail body, separated so it can be rendered without providers.
class FeaturedRailContent extends StatelessWidget {
  const FeaturedRailContent({
    super.key,
    required this.items,
    required this.selected,
    required this.now,
    required this.onFilter,
    required this.onSeeAll,
    required this.onTap,
  });

  final List<FeaturedProgramme> items;
  final FeaturedKind? selected;
  final DateTime now;
  final ValueChanged<FeaturedKind?> onFilter;
  final ValueChanged<FeaturedKind?> onSeeAll;
  final ValueChanged<FeaturedProgramme> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
          child: Row(
            children: [
              const Text(
                'Featured tonight',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => onSeeAll(selected),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              FeaturedFilterChip(
                label: 'All',
                selected: selected == null,
                onTap: () => onFilter(null),
              ),
              for (final kind in FeaturedKind.values)
                FeaturedFilterChip(
                  label: kind.pluralLabel,
                  selected: selected == kind,
                  onTap: () => onFilter(kind),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          SizedBox(
            height: FeaturedCard.height,
            child: Center(
              child: Text(
                'No ${(selected?.pluralLabel ?? 'featured').toLowerCase()} '
                'highlights right now.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: FeaturedCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return FeaturedCard(
                  item: item,
                  now: now,
                  onTap: () => onTap(item),
                );
              },
            ),
          ),
        const SizedBox(height: 2),
      ],
    );
  }
}

class _GuidePrompt extends StatelessWidget {
  const _GuidePrompt({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _RailNotice extends StatelessWidget {
  const _RailNotice({required this.text, this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          if (busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            )
          else
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppTheme.textMuted,
            ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RailError extends StatelessWidget {
  const _RailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppTheme.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'TV guide unavailable',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
