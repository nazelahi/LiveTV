import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../providers/playlist_providers.dart';
import '../providers/epg_providers.dart';
import '../providers/update_provider.dart';
import '../screens/epg_screen.dart';
import '../widgets/glass.dart';
import 'dart:io';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _refreshing = false;

  String? _latestVersion;
  String? _latestReleaseUrl;
  static const MethodChannel _updateChannel = MethodChannel('app_update');
  bool _downloadingUpdate = false;
  double _downloadProgress = 0;
  String? _latestDownloadUrl;
  bool _checkingUpdate = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(playlistProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Playlist updated')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not refresh. The saved playlist is still in use.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved playlist?'),
        content: const Text(
          'The playlist will be downloaded again from its source. '
          'You will need an internet connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(playlistProvider.notifier).clearCache();
    ref.invalidate(playlistProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved playlist cleared')));
  }

  Future<void> _toggleAdult(bool value) async {
    if (!value) {
      ref.read(settingsProvider.notifier).setShowAdult(false);
      return;
    }

    final adultCount = ref
            .read(playlistProvider)
            .valueOrNull
            ?.channels
            .where((channel) => channel.group == AppConfig.adultGroup)
            .length ??
        0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Show adult channels?'),
        content: Text(
          adultCount == 0
              ? 'This playlist contains an adult section. When enabled, those '
                  'channels appear in the list and in search results.'
              : 'This playlist contains $adultCount adult channels. When enabled, '
                  'they appear in the list and in search results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Show'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(settingsProvider.notifier).setShowAdult(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final playlist = ref.watch(playlistProvider);
    final state = playlist.valueOrNull;
    final adultCount = state?.channels
            .where((channel) => channel.group == AppConfig.adultGroup)
            .length ??
        0;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10 + MediaQuery.of(context).padding.top,
                10,
                10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundAlt,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.textMuted.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 19,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${AppConfig.appName} ${AppConfig.appVersion}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 80),
                children: [
            const SizedBox(height: 14),
            const _SectionLabel('Content'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  value: settings.showAdult,
                  onChanged: _toggleAdult,
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Show adult channels'),
                  subtitle: Text(
                    settings.showAdult
                        ? 'Adult channels are visible'
                        : '$adultCount channels hidden',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionLabel('Playback'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  value: settings.autoplay,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setAutoplay(value),
                  secondary: const Icon(Icons.play_circle_outline_rounded),
                  title: const Text('Autoplay'),
                  subtitle: const Text(
                    'Start the stream as soon as a channel is opened',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  value: settings.compatibilityMode,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setCompatibilityMode(value),
                  secondary: const Icon(Icons.build_circle_outlined),
                  title: const Text('Compatibility mode'),
                  subtitle: const Text(
                    'Software decoding and a larger buffer for stubborn streams',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionLabel('Playlist'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.live_tv_outlined),
                  title: const Text('Channels'),
                  subtitle: Text(
                    state == null
                        ? 'Not loaded'
                        : '${formatCount(state.channels.length)} channels in '
                            '${state.groups.length} categories',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Last updated'),
                  subtitle: Text(timeAgo(state?.updatedAt)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _refreshing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh playlist'),
                  subtitle: const Text('Download the latest channel list'),
                  enabled: !_refreshing,
                  onTap: _refresh,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Clear saved playlist'),
                  subtitle: const Text('Forces a fresh download from its source'),
                  onTap: _clearCache,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionLabel('About'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: Text(
                    '${AppConfig.appName} ${AppConfig.appVersion}',
                  ),
                  onTap: _showAbout,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.system_update_rounded),
                  title: const Text('App version'),
                  subtitle: Text(
                    _checkingUpdate
                        ? 'Checking for updates…'
                        : _latestVersion == null
                            ? ((kIsWeb || !Platform.isAndroid) ? AppConfig.appVersion : '${AppConfig.appVersion}  ·  tap to check for updates')
                            : _latestVersion == AppConfig.appVersion
                                ? '${AppConfig.appVersion}  ·  up to date'
                                : '${AppConfig.appVersion}  →  $_latestVersion available',
                  ),
                  trailing: (kIsWeb || !Platform.isAndroid) ? null : _checkingUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _downloadingUpdate
                          ? SizedBox(
                              width: 60,
                              child: LinearProgressIndicator(
                                value: _downloadProgress > 0 ? _downloadProgress : null,
                              ),
                            )
                          : (_latestVersion != null &&
                                  _latestVersion != AppConfig.appVersion)
                              ? TextButton(
                                  onPressed: _downloadAndInstallUpdate,
                                  child: const Text('Update'),
                                )
                              : IconButton(
                              tooltip: 'Check for updates',
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: _checkForUpdates,
                            ),
                  onTap: (kIsWeb || !Platform.isAndroid || _checkingUpdate || _downloadingUpdate)
                       ? null
                       : _checkForUpdates,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Playlist source'),
                  subtitle: SelectableText(
                    ref.watch(playlistSourceUrlProvider),
                    style: const TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _EpgTile(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Playlist by SAEID RAHMAN · BDIX-IPTV\n'
              'This app is a player only. Streams are provided by the '
              'playlist author.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ), // ListView
      ), // Expanded
    ], // Column children
  ), // Column
), // SafeArea
); // Scaffold
  }


  Future<void> _downloadAndInstallUpdate() async {
    final url = _latestDownloadUrl ?? _latestReleaseUrl;
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No download link available.')));
      return;
    }

    // Ensure install permission on Android 8+.
    try {
      final canInstall = await _updateChannel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        await _updateChannel.invokeMethod('openInstallPermissionSettings');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Allow installs from this app, then retry.')),
          );
        return;
      }
    } catch (_) {
      // Ignore; proceed to download.
    }

    setState(() {
      _downloadingUpdate = true;
      _downloadProgress = 0;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'LiveTV-App';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final file = File('${Directory.systemTemp.path}/LiveTV-update.apk');
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      }
      await sink.close();
      client.close();

      if (!mounted) return;
      await _updateChannel.invokeMethod('installApk', {'path': file.path});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _downloadingUpdate = false);
    }
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                size: 24,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'v${AppConfig.appVersion}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A live TV player for Android and the web. Browse channels by '
              'category, mark favourites, and discover tonight\'s movies, '
              'sports, news and shows from the TV guide.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _AboutRow(label: 'Version', value: AppConfig.appVersion),
            _AboutRow(label: 'Playlist', value: 'BDIX-IPTV by Saeid Rahman'),
            _AboutRow(label: 'TV guide', value: 'XMLTV (EPG)'),
            const SizedBox(height: 12),
            SelectableText(
              AppConfig.sourceUrl,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '© ${DateTime.now().year} ${AppConfig.appName}',
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    ref.invalidate(latestReleaseProvider);
    final info = await ref.read(latestReleaseProvider.future).catchError((_) => null);
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _latestVersion = info?.version;
      _latestReleaseUrl = info?.releaseUrl;
      _latestDownloadUrl = info?.downloadUrl;
      if (_latestVersion == AppConfig.appVersion) {
        _latestReleaseUrl = null;
        _latestDownloadUrl = null;
      }
    });

    if (info == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Update check failed: no release info')),
        );
      return;
    }
    if (info.isNewer) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Update available: ${info.version}')),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('You\'re on the latest version (${AppConfig.appVersion})')),
        );
    }
  }
}





class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmAndDownloadEpg(
  BuildContext context,
  EpgNotifier notifier,
) async {
  if (kIsWeb) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download TV guide?'),
        content: const Text(
          'The guide file is about 69 MB and will be stored in your browser. '
          'This may take a while. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  notifier.download();
}

class _EpgTile extends ConsumerWidget {
  const _EpgTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epg = ref.watch(epgProvider);
    final notifier = ref.read(epgProvider.notifier);

    return epg.when(
      loading: () => const ListTile(
        leading: Icon(Icons.subtitles_outlined),
        title: Text('TV guide (EPG)'),
        subtitle: Text('Downloading guide…'),
        trailing: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.subtitles_outlined),
        title: const Text('TV guide (EPG)'),
        subtitle: Text('Download failed: $error'),
        trailing: IconButton(
          tooltip: 'Retry',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _confirmAndDownloadEpg(context, notifier),
        ),
      ),
      data: (data) {
        if (data == null) {
          return ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('TV guide (EPG)'),
            subtitle: const Text(
              'Not downloaded. The guide file is about 69 MB.',
            ),
            trailing: FilledButton(
              onPressed: () => _confirmAndDownloadEpg(context, notifier),
              child: const Text('Download'),
            ),
          );
        }

        return ListTile(
          leading: const Icon(Icons.subtitles_outlined),
          title: const Text('TV guide (EPG)'),
          subtitle: Text(
            '${data.channelCount} channels · ${data.programmeCount} programmes\n'
            'Updated ${_timeAgo(data.fetchedAt)}',
          ),
          isThreeLine: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EpgScreen()),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _confirmAndDownloadEpg(context, notifier),
              ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => notifier.clear(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppTheme.accent.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 12,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: Column(children: children),
      ),
    );
  }
}
