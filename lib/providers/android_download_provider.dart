import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/playlist_repository.dart';
import '../providers/update_provider.dart';
import 'playlist_providers.dart';

/// Resolved, ready-to-render configuration for the web Android download
/// banner. Remote config takes precedence, then the GitHub releases API,
/// then `AppConfig` constants, then the built-in fallback URL.
class AndroidDownloadConfig {
  const AndroidDownloadConfig({
    required this.enabled,
    required this.url,
    this.version,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final bool enabled;
  final String url;
  final String? version;
  final String title;
  final String subtitle;
  final String buttonLabel;
}

String _nonEmpty(String? value) => (value != null && value.trim().isNotEmpty)
    ? value.trim()
    : '';

final androidDownloadConfigProvider =
    FutureProvider<AndroidDownloadConfig>((ref) async {
  final repo = ref.read(playlistRepositoryProvider);
  RemoteConfig? remote;
  try {
    remote = await repo.fetchRemoteConfig();
  } catch (_) {
    remote = null;
  }

  AppUpdateInfo? github;
  try {
    github = await ref.read(latestReleaseProvider.future);
  } catch (_) {
    github = null;
  }

  final enabled = remote?.androidDownloadEnabled ?? AppConfig.androidDownloadEnabled;

  final title = _nonEmpty(remote?.androidDownloadTitle).isNotEmpty
      ? _nonEmpty(remote?.androidDownloadTitle)
      : AppConfig.androidDownloadTitle;

  final subtitle = _nonEmpty(remote?.androidDownloadSubtitle).isNotEmpty
      ? _nonEmpty(remote?.androidDownloadSubtitle)
      : AppConfig.androidDownloadSubtitle;

  final buttonLabel = _nonEmpty(remote?.androidDownloadButton).isNotEmpty
      ? _nonEmpty(remote?.androidDownloadButton)
      : AppConfig.androidDownloadButton;

  final remoteVersion = _nonEmpty(remote?.androidDownloadVersion);
  final version = remoteVersion.isNotEmpty
      ? remoteVersion
      : (github?.version ?? '');

  String url;
  final remoteUrl = _nonEmpty(remote?.androidDownloadUrl);
  if (remoteUrl.isNotEmpty) {
    url = remoteUrl;
  } else if (github?.downloadUrl != null && github!.downloadUrl!.isNotEmpty) {
    url = github.downloadUrl!;
  } else if (github?.releaseUrl != null && github!.releaseUrl!.isNotEmpty) {
    url = github.releaseUrl!;
  } else if (AppConfig.androidDownloadUrl.isNotEmpty) {
    url = AppConfig.androidDownloadUrl;
  } else {
    url = 'https://github.com/nazelahi/LiveTV/releases/latest';
  }

  return AndroidDownloadConfig(
    enabled: enabled,
    url: url,
    version: version.isEmpty ? null : version,
    title: title,
    subtitle: subtitle,
    buttonLabel: buttonLabel,
  );
});