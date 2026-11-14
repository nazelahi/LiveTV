import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/utils.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    this.downloadUrl,
    this.releaseUrl,
    this.checksum,
  });

  final String version;
  final String? downloadUrl;
  final String? releaseUrl;

  /// Expected SHA-256 hex digest of the APK, when published alongside the
  /// release. Used to verify the downloaded file before installing it.
  final String? checksum;

  bool get isNewer => isNewerVersion(version, AppConfig.appVersion);
}

final latestReleaseProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  if (AppConfig.appReleaseUrl.isEmpty) return null;
  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse(AppConfig.appReleaseUrl),
          headers: const {'User-Agent': 'LiveTV-App', 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));
    client.close();
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final tag = decoded['tag_name']?.toString();
    if (tag == null || tag.isEmpty) return null;

    final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
    String? downloadUrl;
    String? checksumUrl;
    String? checksum;
    final assets = decoded['assets'];
    if (assets is List) {
      // Prefer an APK asset.
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final name = a['name']?.toString() ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            downloadUrl ??= a['browser_download_url']?.toString();
          }
          // Look for a sidecar checksum file.
          if (name.toLowerCase().endsWith('.sha256') ||
              name.toLowerCase() == 'sha256sums' ||
              name.toLowerCase() == 'checksums.txt') {
            checksumUrl ??= a['browser_download_url']?.toString();
          }
        }
      }
      if (downloadUrl == null && assets.isNotEmpty && assets.first is Map) {
        downloadUrl = (assets.first as Map)['browser_download_url']?.toString();
      }
    }

    // Fetched only after every asset was seen, so the APK name is known and
    // the matching line is picked regardless of the order GitHub lists them.
    if (checksumUrl != null) {
      try {
        final c = http.Client();
        final r = await c
            .get(Uri.parse(checksumUrl))
            .timeout(const Duration(seconds: 15));
        c.close();
        if (r.statusCode == 200) {
          checksum = extractChecksum(r.body, downloadUrl);
        }
      } catch (_) {
        // Checksum is best-effort; never block the update check.
      }
    }

    return AppUpdateInfo(
      version: version,
      downloadUrl: downloadUrl,
      releaseUrl: decoded['html_url']?.toString(),
      checksum: checksum,
    );
  } catch (_) {
    return null;
  }
});

/// Pulls a 64-hex-char SHA-256 digest out of a checksum file's contents,
/// preferring the line that names the APK at [apkUrl].
String? extractChecksum(String body, String? apkUrl) {
  final apkName = apkUrl == null
      ? null
      : Uri.decodeComponent(Uri.parse(apkUrl).pathSegments.last);
  String? onlyHash;
  var hashes = 0;
  for (final line in body.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    // Format: "<hash>  <filename>" or "<hash> *<filename>" or bare hash.
    final match = RegExp(r'^([0-9a-fA-F]{64})(?:\s+\*?(.+))?$').firstMatch(trimmed);
    if (match == null) continue;
    final hash = match.group(1)!.toLowerCase();
    final fileName = match.group(2)?.trim();
    if (apkName == null) return hash;
    if (fileName != null && fileName.split('/').last == apkName) return hash;
    hashes++;
    onlyHash = hash;
  }
  // A file with a single digest (the usual .sha256 sidecar) belongs to the
  // APK; with several, guessing could reject a valid download.
  return hashes == 1 ? onlyHash : null;
}