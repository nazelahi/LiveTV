import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/models/channel.dart';
import '../providers/playlist_providers.dart';
import 'watch_screen.dart';

/// Pure helper: extracts a channel id from a web deep-link route name.
/// Accepts `#/watch/<id>`, `/watch/<id>`, and URL-encoded forms.
String? parseWatchDeepLink(String name) {
  // Strip any leading scheme/host that Flutter may include.
  var value = name.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.hasFragment || uri.path.isNotEmpty)) {
    if (uri.fragment.isNotEmpty) {
      value = uri.fragment;
    } else if (uri.path.isNotEmpty) {
      value = uri.path;
    }
  }
  // Normalise: strip leading "/" then expect "watch/<id>".
  value = value.replaceFirst(RegExp(r'^/+'), '');
  if (!value.startsWith('watch/')) {
    value = value.replaceFirst(RegExp(r'^#/?'), '');
    if (!value.startsWith('watch/')) return null;
  }
  final rest = value.substring('watch/'.length);
  if (rest.isEmpty) return null;
  try {
    return Uri.decodeComponent(rest);
  } catch (_) {
    return rest;
  }
}

class DeepLinkWatchScreen extends ConsumerStatefulWidget {
  const DeepLinkWatchScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<DeepLinkWatchScreen> createState() =>
      _DeepLinkWatchScreenState();
}

class _DeepLinkWatchScreenState extends ConsumerState<DeepLinkWatchScreen> {
  List<Channel>? _queue;
  int? _index;

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(playlistProvider);
    final data = playlist.valueOrNull;
    if (_queue == null && data != null) {
      final idx = data.channels.indexWhere((c) => c.id == widget.channelId);
      if (idx >= 0) {
        _queue = data.channels;
        _index = idx;
      }
    }

    if (_queue != null && _index != null) {
      return WatchScreen(queue: _queue!, initialIndex: _index!);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('LiveTV'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: playlist.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text(
            'Failed to load playlist: $e',
            textAlign: TextAlign.center,
          ),
          data: (d) {
            final found = d.channels.any((c) => c.id == widget.channelId);
            return Text(
              found ? 'Loading…' : 'Channel not found: ${widget.channelId}',
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
    );
  }
}