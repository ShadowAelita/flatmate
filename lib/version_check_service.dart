import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  VersionCheckService._private();

  static final VersionCheckService instance = VersionCheckService._private();

  static const String _versionJsonUrl =
      'https://raw.githubusercontent.com/ShadowAelita/flatmate-updates/main/version.json';

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
          apkUrl: null,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String;
      final releaseUrl = data['release_url'] as String?;
      final apkUrl = data['apk_url'] as String?;

      final hasUpdate = _isNewerVersion(current, latestVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: current,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        apkUrl: apkUrl,
      );
    } catch (e) {
      debugPrint('VersionCheckService: Update check failed: $e');
      final current = await currentVersion;

      return VersionCheckResult(
        hasUpdate: false,
        currentVersion: current,
        latestVersion: current,
        releaseUrl: null,
        apkUrl: null,
      );
    }
  }

  static Future<void> openReleaseUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<bool> downloadAndInstallApk({
    required String apkUrl,
    required String releaseUrl,
    required void Function(double progress, String? status) onProgress,
  }) async {
    if (kIsWeb) {
      onProgress(0, 'Öffne Release-Seite...');
      await openReleaseUrl(releaseUrl);

      return false;
    }

    if (!Platform.isAndroid) {
      onProgress(0, 'Öffne App Store...');
      await openReleaseUrl(releaseUrl);

      return false;
    }

    final client = HttpClient();
    String? filePath;

    try {
      final directory = await getTemporaryDirectory();
      filePath = '${directory.path}/flatmate_update.apk';
      final file = File(filePath);

      final request = await client.getUrl(Uri.parse(apkUrl));
      final response = await request.close();

      final contentLength = response.contentLength;
      final sink = file.openWrite(mode: FileMode.write);

      int received = 0;
      var hasError = false;

      onProgress(0, 'Lade APK herunter...');

      await response.listen(
        (data) {
          sink.add(data);
          received += data.length;
          if (contentLength != -1) {
            onProgress(received / contentLength, null);
          }
        },
        onError: (e) {
          hasError = true;
        },
        onDone: () {
          onProgress(1.0, 'Fertig!');
        },
      ).asFuture();

      await sink.close();
      client.close();

      if (hasError || received == 0) {
        if (await file.exists()) {
          await file.delete();
        }

        return false;
      }

      onProgress(1.0, 'Installiere...');
      await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      return true;
    } catch (e) {
      debugPrint('VersionCheckService: Download/install failed: $e');

      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      return false;
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
  final String? apkUrl;

  const VersionCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.apkUrl,
  });
}
