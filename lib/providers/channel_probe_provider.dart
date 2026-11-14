import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/stream_probe.dart';
import '../data/models/channel.dart';
import 'dead_channels_provider.dart';

/// Runs a bounded-concurrency probe over the channel list and marks the broken
/// ones in [deadChannelsProvider]. Designed to run in the background: the UI
/// stays responsive and channels disappear as they are confirmed dead.
class ChannelProbeController {
  ChannelProbeController(this._ref);

  final Ref _ref;

  bool _running = false;

  /// Bumped by every [run]; an older run stops once a newer one starts.
  int _generation = 0;
  List<Channel>? _channels;

  /// Probes [channels] and returns once every channel has been checked.
  ///
  /// A new call supersedes a run that is still in progress, so a freshly
  /// downloaded playlist is always probed. Pass [restart] to probe the same
  /// list again, e.g. after the dead set was cleared.
  Future<void> run(List<Channel> channels, {bool restart = false}) async {
    // Probing streams from the browser is blocked by CORS for most hosts and
    // only adds noise; skip it on web.
    if (kIsWeb) return;
    if (channels.isEmpty) return;
    // The home screen and desktop shell can both ask for the same list.
    if (!restart && _running && identical(channels, _channels)) return;
    final generation = ++_generation;
    _channels = channels;
    _running = true;
    final client = http.Client();
    try {
      final dead = _ref.read(deadChannelsProvider.notifier);
      const concurrency = 20;
      final pending = <Future<void>>[];

      Future<void> probeOne(Channel channel) async {
        if (generation != _generation) return;
        var ok = await probeStream(client, channel.url);
        // One slow or flaky answer is not enough to hide a channel: retry
        // once with a longer timeout before marking it dead.
        if (!ok && generation == _generation) {
          ok = await probeStream(
            client,
            channel.url,
            timeout: const Duration(seconds: 8),
          );
        }
        if (!ok && generation == _generation) dead.markDead(channel.id);
      }

      for (final channel in channels) {
        if (generation != _generation) break;
        if (pending.length >= concurrency) {
          await Future.wait(pending);
          pending.clear();
        }
        pending.add(probeOne(channel));
      }
      if (pending.isNotEmpty) await Future.wait(pending);
    } finally {
      client.close();
      if (generation == _generation) _running = false;
    }
  }

  bool get isRunning => _running;
}

final channelProbeControllerProvider = Provider<ChannelProbeController>((ref) {
  return ChannelProbeController(ref);
});