import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// A popup menu button that lists the available video tracks of [player] and
/// lets the user switch quality/rendition.
class QualityButton extends StatelessWidget {
  const QualityButton({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (context, tracksSnapshot) {
        final tracks = tracksSnapshot.data?.video ?? const <VideoTrack>[];
        final options = tracks.where((t) => t.id != 'no').toList();
        if (options.length <= 1) return const SizedBox.shrink();
        return StreamBuilder<Track>(
          stream: player.stream.track,
          initialData: player.state.track,
          builder: (context, trackSnapshot) {
            final current = trackSnapshot.data?.video;
            return PopupMenuButton<VideoTrack>(
              tooltip: 'Quality',
              icon: const Icon(Icons.high_quality_rounded),
              onSelected: (track) => player.setVideoTrack(track),
              itemBuilder: (context) => options.map((track) {
                final selected = track == current;
                return PopupMenuItem<VideoTrack>(
                  value: track,
                  child: Row(
                    children: [
                      if (selected)
                        const Icon(Icons.check_rounded, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 6),
                      Text(_label(track)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  static String _label(VideoTrack track) {
    if (track.id == 'auto') return 'Auto';
    final parts = <String>[];
    if (track.w != null && track.h != null) {
      parts.add('${track.w}x${track.h}');
    }
    if (track.bitrate != null && track.bitrate! > 0) {
      parts.add('${(track.bitrate! / 1000).round()} kbps');
    }
    if (parts.isEmpty && track.title != null && track.title!.isNotEmpty) {
      parts.add(track.title!);
    }
    return parts.isEmpty ? track.id : parts.join(' · ');
  }
}