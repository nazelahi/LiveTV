import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/featured_programs.dart';
import '../screens/epg_screen.dart';
import '../screens/watch_screen.dart';
import 'featured_visuals.dart';

Future<void> showProgrammeDetails(
  BuildContext context,
  FeaturedProgramme item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProgrammeDetailsSheet(item: item),
  );
}

class _ProgrammeDetailsSheet extends StatelessWidget {
  const _ProgrammeDetailsSheet({required this.item});

  final FeaturedProgramme item;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final programme = item.programme;
    final live = programme.isLiveAt(now);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProgrammeBackdrop(
                          programme: programme,
                          channel: item.channel,
                          kind: item.kind,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: FeaturedKindBadge(kind: item.kind),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FeaturedStatusChip(
                            label: live
                                ? 'LIVE'
                                : featuredStartLabel(programme, now),
                            live: live,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  programme.title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${featuredLongDate(programme, now)} · '
                  '${featuredTimeRange(programme)} · '
                  '${featuredDuration(programme)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _ChannelRow(item: item),
                if (programme.description != null &&
                    programme.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    programme.description!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => _watch(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(live ? 'Watch live' : 'Watch channel'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGuide(context),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Channel guide'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _watch(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(queue: [item.channel], initialIndex: 0),
      ),
    );
  }

  void _openGuide(BuildContext context) {
    final tvgId = item.channel.tvgId?.trim();
    final channelId =
        tvgId != null && tvgId.isNotEmpty ? tvgId : item.channel.id;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => EpgChannelScreen(
          channelId: channelId,
          title: item.channel.name,
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.item});

  final FeaturedProgramme item;

  @override
  Widget build(BuildContext context) {
    final logo = item.channel.logo?.trim();
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30,
            height: 30,
            color: Colors.white.withValues(alpha: 0.06),
            child: logo != null && logo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.contain,
                    memCacheWidth: 120,
                    imageRenderMethodForWeb: kIsWeb
                        ? ImageRenderMethodForWeb.HttpGet
                        : ImageRenderMethodForWeb.HtmlImage,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.live_tv_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  )
                : const Icon(
                    Icons.live_tv_rounded,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item.channel.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
