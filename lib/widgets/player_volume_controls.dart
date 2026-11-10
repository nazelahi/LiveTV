import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';

/// A mute toggle button that stays in sync with [playerProvider].
class PlayerMuteButton extends ConsumerWidget {
  const PlayerMuteButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playerProvider);
    final muted = session?.muted ?? false;
    return IconButton(
      tooltip: muted ? 'Unmute' : 'Mute',
      onPressed: () => ref.read(playerProvider.notifier).toggleMute(),
      icon: Icon(
        muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: color,
      ),
    );
  }
}

/// A volume slider that stays in sync with [playerProvider].
class PlayerVolumeSlider extends ConsumerWidget {
  const PlayerVolumeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playerProvider);
    final volume = session?.volume ?? 100.0;
    return Slider(
      value: volume.clamp(0.0, 100.0),
      min: 0,
      max: 100,
      activeColor: Colors.white,
      inactiveColor: Colors.white24,
      thumbColor: Colors.white,
      onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
    );
  }
}