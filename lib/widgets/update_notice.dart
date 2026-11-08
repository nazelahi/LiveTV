import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/update_provider.dart';
import '../screens/settings_screen.dart';

/// A banner shown on the Home screen when a newer app release is published.
class UpdateNotice extends ConsumerWidget {
  const UpdateNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(latestReleaseProvider);
    final info = async.valueOrNull;
    if (info == null || !info.isNewer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, size: 20, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update available: ${info.version}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'A new version of LiveTV is available.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
