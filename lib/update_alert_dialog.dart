import 'package:flutter/material.dart';

import 'version_check_service.dart';

class UpdateAlertDialog extends StatelessWidget {
  const UpdateAlertDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String? releaseUrl;

  static Future<void> show({
    required BuildContext context,
    required String currentVersion,
    required String latestVersion,
    required String? releaseUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateAlertDialog(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
      ),
    ).then((_) async {
      if (context.mounted && releaseUrl != null) {
        await VersionCheckService.openReleaseUrl(releaseUrl);
      }
    });
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
          const SizedBox(height: 8),
          const Text(
            'Es ist ein neues Update verfügbar. '
            'Bitte aktualisiere die App für die neuesten Funktione.',
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
          onPressed: () async {
            Navigator.of(context).pop();

            if (releaseUrl != null) {
              await VersionCheckService.openReleaseUrl(releaseUrl!);
            }
          },
          child: const Text('Jetzt aktualisieren'),
        ),
      ],
    );
  }
}
