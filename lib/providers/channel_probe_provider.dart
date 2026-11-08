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

  /// Probes [channels] and returns once every channel has been checked.
  Future<void> run(List<Channel> channels) async {
    // Probing streams from the browser is blocked by CORS for most hosts and
    // only adds noise; skip it on web.
    if (kIsWeb) return;
    if (_running || channels.isEmpty) return;
    _running = true;
    try {
      final client = http.Client();
      final dead = _ref.read(deadChannelsProvider.notifier);
      const concurrency = 20;
      final pending = <Future<void>>[];

      Future<void> probeOne(Channel channel) async {
        final ok = await probeStream(client, channel.url);
        if (!ok) dead.markDead(channel.id);
      }

      for (final channel in channels) {
        if (pending.length >= concurrency) {
          await Future.wait(pending);
          pending.clear();
        }
        pending.add(probeOne(channel));
      }
      if (pending.isNotEmpty) await Future.wait(pending);
      client.close();
    } finally {
      _running = false;
    }
  }

  bool get isRunning => _running;
}

final channelProbeControllerProvider = Provider<ChannelProbeController>((ref) {
  return ChannelProbeController(ref);
});