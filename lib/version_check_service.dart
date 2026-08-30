import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  VersionCheckService._private();

  static final VersionCheckService instance = VersionCheckService._private();

  static const String _versionJsonUrl =
      'https://raw.githubusercontent.com/lukicm/flatmate-updates/main/version.json';

  String? _cachedCurrentVersion;

  Future<String> get currentVersion async {
    if (_cachedCurrentVersion != null) {
      return _cachedCurrentVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      _cachedCurrentVersion = info.version;
      return _cachedCurrentVersion!;
    } catch (e) {
      debugPrint('VersionCheckService: Could not get package info: $e');
      _cachedCurrentVersion = '0.0.0';
      return _cachedCurrentVersion!;
    }
  }

  Future<VersionCheckResult> checkForUpdates() async {
    try {
      final current = await currentVersion;

      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return VersionCheckResult(
          hasUpdate: false,
          currentVersion: current,
          latestVersion: current,
          releaseUrl: null,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String;
      final releaseUrl = data['release_url'] as String?;

      final hasUpdate = _isNewerVersion(current, latestVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: current,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
      );
    } catch (e) {
      debugPrint('VersionCheckService: Update check failed: $e');
      final current = await currentVersion;

      return VersionCheckResult(
        hasUpdate: false,
        currentVersion: current,
        latestVersion: current,
        releaseUrl: null,
      );
    }
  }

  static Future<void> openReleaseUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    final currentParts = _parseVersion(current);
    final latestParts = _parseVersion(latest);

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    return false;
  }

  static List<int> _parseVersion(String version) {
    final parts = version.split('.');

    return [
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }
}

class VersionCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? releaseUrl;

  const VersionCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
  });
}
