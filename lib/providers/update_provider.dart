import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    this.downloadUrl,
    this.releaseUrl,
  });

  final String version;
  final String? downloadUrl;
  final String? releaseUrl;

  bool get isNewer => version != AppConfig.appVersion;
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
    final assets = decoded['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final name = a['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = a['browser_download_url']?.toString();
            break;
          }
        }
      }
      downloadUrl ??= (assets.isNotEmpty && assets.first is Map)
          ? (assets.first as Map)['browser_download_url']?.toString()
          : null;
    }

    return AppUpdateInfo(
      version: version,
      downloadUrl: downloadUrl,
      releaseUrl: decoded['html_url']?.toString(),
    );
  } catch (_) {
    return null;
  }
});
