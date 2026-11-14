import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/models/channel.dart';
import '../data/models/epg.dart';
import '../data/models/playlist_state.dart';
import '../core/notifications.dart';
import '../providers/epg_providers.dart';
import '../providers/playlist_providers.dart';
import '../providers/reminder_provider.dart';

class EpgScreen extends ConsumerStatefulWidget {
  const EpgScreen({super.key});

  @override
  ConsumerState<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends ConsumerState<EpgScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epgState = ref.watch(epgProvider);
    final playlist = ref.watch(playlistProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: epgState.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading TV guide…'),
              ],
            ),
          ),
          error: (error, _) => _ErrorView(
            message: error.toString(),
            onRetry: () => ref.read(epgProvider.notifier).download(),
          ),
          data: (data) {
            if (data == null) {
              return _DownloadPrompt(
                onDownload: () => ref.read(epgProvider.notifier).download(),
              );
            }
            return _GuideView(
              data: data,
              playlist: playlist,
              query: _query,
              searchController: _searchController,
              onQueryChanged: (value) => setState(() => _query = value),
            );
          },
        ),
      ),
    );
  }
}

class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 56, color: AppTheme.accent),
            const SizedBox(height: 12),
            const Text(
              'TV guide not downloaded',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Download the full programme guide (~69 MB). '
              'This may take a while on a slow connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download guide'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppTheme.danger),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({
    required this.data,
    required this.playlist,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
  });

  final EpgData data;
  final PlaylistState? playlist;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final channels = playlist?.channels ?? const <Channel>[];
    final items = <_ChannelItem>[];

    if (channels.isNotEmpty) {
      for (final channel in channels) {
        final key = channel.tvgId ?? channel.id;
        if (data.hasChannel(key)) {
          items.add(_ChannelItem(channel: channel, epgId: key));
        }
      }
    }

    if (items.isEmpty) {
      for (final id in data.byChannel.keys) {
        items.add(_ChannelItem(channel: null, epgId: id));
      }
    }

    final filtered = query.trim().isEmpty
        ? items
        : items.where((item) {
            final name = item.channel?.name ?? item.epgId;
            final now = data.now(item.epgId);
            final haystack =
                '$name ${now?.title ?? ''}'.toLowerCase();
            return haystack.contains(query.trim().toLowerCase());
          }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search guide',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${data.channelCount} ch',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching channels'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final name = item.channel?.name ?? item.epgId;
                    final now = data.now(item.epgId);
                    final next = data.next(item.epgId);
                    return _GuideTile(
                      name: name,
                      logo: item.channel?.logo,
                      now: now,
                      next: next,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EpgChannelScreen(
                            channelId: item.epgId,
                            title: name,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChannelItem {
  const _ChannelItem({required this.channel, required this.epgId});

  final Channel? channel;
  final String epgId;
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.name,
    required this.logo,
    required this.now,
    required this.next,
    required this.onTap,
  });

  final String name;
  final String? logo;
  final Programme? now;
  final Programme? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 30,
                child: logo != null && logo!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logo!,
                        fit: BoxFit.cover,
                        memCacheWidth: 88,
                        imageRenderMethodForWeb: kIsWeb
                            ? ImageRenderMethodForWeb.HtmlImage
                            : ImageRenderMethodForWeb.HtmlImage,
                        errorWidget: (_, _, _) => _fallback(name),
                      )
                    : _fallback(name),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (now != null)
                    Text(
                      'Now: ${now!.title}  '
                      '(${_time(now!.start)}–${_time(now!.stop)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.accent,
                      ),
                    )
                  else
                    Text(
                      'No current programme',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  if (next != null)
                    Text(
                      'Next: ${next!.title}  (${_time(next!.start)})',
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _fallback(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      color: AppTheme.textSecondary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class EpgChannelScreen extends StatelessWidget {
  const EpgChannelScreen({
    super.key,
    required this.channelId,
    required this.title,
  });

  final String channelId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Consumer(
        builder: (context, ref, _) {
          final data = ref.watch(epgProvider).valueOrNull;
          final programmes = data?.programmesFor(channelId) ?? const [];
          if (programmes.isEmpty) {
            return const Center(child: Text('No programmes available'));
          }
          final now = DateTime.now();
          return ListView.builder(
            itemCount: programmes.length,
            itemBuilder: (context, index) {
              final programme = programmes[index];
              final isLive = !programme.start.isAfter(now) &&
                  programme.stop.isAfter(now);
              return Container(
                color: isLive
                    ? AppTheme.accent.withValues(alpha: 0.08)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_fmt(programme.start)} – ${_fmt(programme.stop)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isLive
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      programme.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (programme.description != null &&
                        programme.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        programme.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (!isLive && programme.start.isAfter(DateTime.now())) ...[
                      const SizedBox(height: 6),
                      Consumer(
                        builder: (context, ref, _) {
                          final notifier = ref.read(reminderProvider.notifier);
                          final reminded = ref.watch(reminderProvider).contains(
                                notifier.keyFor(channelId, programme.start),
                              );
                          return TextButton.icon(
                            // Local notifications cannot be scheduled from the
                            // web build; disable instead of failing silently.
                            onPressed: kIsWeb
                                ? null
                                : () async {
                                    if (!context.mounted) return;
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    await ReminderNotifications
                                        .requestPermission();
                                    final result = await notifier.toggle(
                                      channelId: channelId,
                                      channelName: title,
                                      programme: programme,
                                    );
                                    final message = result.message;
                                    if (message != null && context.mounted) {
                                      messenger
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                          content: Text(message),
                                        ));
                                    }
                                  },
                            icon: Icon(
                              reminded
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              size: 16,
                            ),
                            label: Text(reminded ? 'Reminder set' : 'Remind me'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}