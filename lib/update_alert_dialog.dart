import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'version_check_service.dart';

class UpdateAlertDialog extends StatelessWidget {
  const UpdateAlertDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.apkUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String? releaseUrl;
  final String? apkUrl;

  static Future<void> show({
    required BuildContext context,
    required String currentVersion,
    required String latestVersion,
    required String? releaseUrl,
    required String? apkUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateAlertDialog(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        apkUrl: apkUrl,
      ),
    );
  }

  static Future<void> showDownloadProgress({
    required BuildContext context,
    required String apkUrl,
    required String releaseUrl,
  }) async {
    final progress = ValueNotifier<double>(0.0);
    final status = ValueNotifier<String>('Vorbereite...');

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Update wird heruntergeladen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, child) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: status,
                builder: (context, value, child) => Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final success = await VersionCheckService.downloadAndInstallApk(
      apkUrl: apkUrl,
      releaseUrl: releaseUrl,
      onProgress: (p, s) {
        progress.value = p;
        if (s != null) status.value = s;
      },
    );

    progress.dispose();
    status.dispose();

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Der Download ist fehlgeschlagen.'),
          action: SnackBarAction(
            label: 'Manuell öffnen',
            onPressed: () {
              VersionCheckService.openReleaseUrl(releaseUrl);
            },
          ),
        ),
      );

      await VersionCheckService.openReleaseUrl(releaseUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update wird installiert...'),
        ),
      );
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    if (releaseUrl == null) return;

    await Clipboard.setData(ClipboardData(text: releaseUrl!));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link in Zwischenablage kopiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: color.surface,
      title: const Text(
        'Update verfügbar',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neue Version: $latestVersion'),
          Text('Aktuelle Version: $currentVersion'),
          const SizedBox(height: 12),
          if (releaseUrl != null) ...[
            Text(
              'Download-Link:',
              style: TextStyle(
                fontSize: 12,
                color: color.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    releaseUrl!,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.primary,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Kopieren',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Es ist ein neues Update verfügbar. '
            'Tippe auf "Jetzt aktualisieren", um die neue Version '
            'automatisch herunterzuladen und zu installieren.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: apkUrl != null
              ? () async {
                  Navigator.of(context).pop();

                  if (context.mounted && apkUrl != null) {
                    await showDownloadProgress(
                      context: context,
                      apkUrl: apkUrl!,
                      releaseUrl: releaseUrl ?? '',
                    );
                  }
                }
              : () async {
                  Navigator.of(context).pop();

                  if (releaseUrl != null) {
                    await VersionCheckService.openReleaseUrl(releaseUrl!);
                  }
                },
          child: Text(
            apkUrl != null ? 'Jetzt aktualisieren' : 'Jetzt aktualisieren',
          ),
        ),
      ],
    );
  }
}
