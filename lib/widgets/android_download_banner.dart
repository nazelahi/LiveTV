import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/open_url.dart';
import '../providers/update_provider.dart';

/// A web-only banner offering a download link to the native Android APK.
class AndroidDownloadBanner extends ConsumerWidget {
  const AndroidDownloadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return const SizedBox.shrink();

    final info = ref.watch(latestReleaseProvider).valueOrNull;
    final url = (info?.downloadUrl != null && info!.downloadUrl!.isNotEmpty)
        ? info.downloadUrl!
        : (info?.releaseUrl != null && info!.releaseUrl!.isNotEmpty)
            ? info.releaseUrl!
            : 'https://github.com/nazelahi/LiveTV/releases/latest';

    final version = info?.version;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentSecondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.android_rounded, size: 24, color: AppTheme.accentSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  version == null
                      ? 'Get the Android app'
                      : 'Get the Android app (v$version)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Download the native app for smoother playback.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => openUrlInNewTab(url),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
