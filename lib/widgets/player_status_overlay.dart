import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Centered status shown over the video surface while a channel is opening or
/// after playback failed, so the player is never just a black rectangle.
class PlayerStatusOverlay extends StatelessWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.channelName,
    this.error,
    this.onRetry,
    this.onNext,
    this.onOpenStream,
    this.onOpenVlc,
  });

  final String channelName;

  /// Non-null switches the overlay from "connecting" to the error state.
  final String? error;

  final VoidCallback? onRetry;
  final VoidCallback? onNext;
  final VoidCallback? onOpenStream;
  final VoidCallback? onOpenVlc;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.textMuted.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failed)
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 32,
                    color: AppTheme.danger,
                  )
                else
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                const SizedBox(height: 12),
                Text(
                  failed
                      ? "$channelName isn't responding"
                      : 'Connecting to $channelName…',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (failed && error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (failed && onRetry != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
                if (failed && onNext != null) ...[
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: onNext,
                    child: const Text('Next channel'),
                  ),
                ],
                if (failed && (onOpenStream != null || onOpenVlc != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (onOpenStream != null)
                        TextButton.icon(
                          onPressed: onOpenStream,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open stream'),
                        ),
                      if (onOpenVlc != null)
                        TextButton.icon(
                          onPressed: onOpenVlc,
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 16),
                          label: const Text('Open in VLC'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
