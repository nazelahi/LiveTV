import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetv/core/constants.dart';
import 'package:livetv/data/playlist_repository.dart';
import 'package:livetv/providers/android_download_provider.dart';
import 'package:livetv/providers/playlist_providers.dart';
import 'package:livetv/providers/update_provider.dart';

class _FakeRepo extends PlaylistRepository {
  _FakeRepo(this.remote) : super();
  final RemoteConfig? remote;
  @override
  Future<RemoteConfig?> fetchRemoteConfig() async => remote;
}

void main() {
  test('uses remote overrides when present', () async {
    final remote = RemoteConfig(
      urls: const ['https://example.com/p.m3u'],
      androidDownloadEnabled: false,
      androidDownloadUrl: 'https://example.com/app.apk',
      androidDownloadVersion: '2.0.0',
      androidDownloadTitle: 'Get it',
      androidDownloadSubtitle: 'Faster',
      androidDownloadButton: 'Install',
    );
    final container = ProviderContainer(overrides: [
      playlistRepositoryProvider.overrideWithValue(_FakeRepo(remote)),
      latestReleaseProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    final cfg = await container.read(androidDownloadConfigProvider.future);
    expect(cfg.enabled, isFalse);
    expect(cfg.url, 'https://example.com/app.apk');
    expect(cfg.version, '2.0.0');
    expect(cfg.title, 'Get it');
    expect(cfg.subtitle, 'Faster');
    expect(cfg.buttonLabel, 'Install');
  });

  test('falls back to constants and hardcoded URL when remote empty', () async {
    final container = ProviderContainer(overrides: [
      playlistRepositoryProvider.overrideWithValue(_FakeRepo(null)),
      latestReleaseProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    final cfg = await container.read(androidDownloadConfigProvider.future);
    expect(cfg.enabled, AppConfig.androidDownloadEnabled);
    expect(cfg.title, AppConfig.androidDownloadTitle);
    expect(cfg.url, 'https://github.com/nazelahi/LiveTV/releases/latest');
  });
}