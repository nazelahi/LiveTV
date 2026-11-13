import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/open_url.dart';
import '../providers/android_download_provider.dart';

/// A web-only banner offering a download link to the native Android APK.
class AndroidDownloadBanner extends ConsumerWidget {
  const AndroidDownloadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return const SizedBox.shrink();

    final config = ref.watch(androidDownloadConfigProvider).valueOrNull ??
        AndroidDownloadConfig(
          enabled: AppConfig.androidDownloadEnabled,
          url: AppConfig.androidDownloadUrl.isNotEmpty
              ? AppConfig.androidDownloadUrl
              : 'https://github.com/nazelahi/LiveTV/releases/latest',
          title: AppConfig.androidDownloadTitle,
          subtitle: AppConfig.androidDownloadSubtitle,
          buttonLabel: AppConfig.androidDownloadButton,
        );

    if (!config.enabled) return const SizedBox.shrink();

    final displayTitle = config.version == null
        ? config.title
        : '${config.title} (v${config.version})';

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
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  config.subtitle,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => openUrlInNewTab(config.url),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(config.buttonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentFill,
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