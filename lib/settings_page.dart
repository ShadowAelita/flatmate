import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_settings_page.dart';
import 'notifications/notification_preferences.dart';
import 'register_page.dart';
import 'update_alert_dialog.dart';
import 'version_check_service.dart';
import 'wg_data.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _showChangeFlatshareConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('WG wechseln?'),
          content: const Text(
            'Du wirst aus deiner aktuellen WG ausgetreten. '
            'Deine lokalen Daten werden gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Wechseln'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await WGData.leaveHousehold();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GatePage()),
      (route) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Abmelden?'),
          content: const Text(
            'Du wirst abgemeldet. '
            'Du kannst dich später wieder anmelden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await WGData.setCurrentMember(null);
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = WGData.currentMember;
    final householdName = WGData.householdName;
    final inviteCode = WGData.inviteCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mein Profil',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: currentMember == null
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : WGData.memberColor(currentMember),
                child: currentMember == null
                    ? const Icon(Icons.person_outline)
                    : Text(
                        currentMember.name.isNotEmpty
                            ? currentMember.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              title: Text(
                currentMember?.name ?? 'Keine Person ausgewählt',
              ),
              subtitle: const Text('Wer bist du?'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showMemberPicker(context);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'WG',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (householdName != null)
                  ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: const Text('Name der WG'),
                    subtitle: Text(householdName),
                  ),
                if (householdName != null) const Divider(height: 1),
                if (inviteCode != null)
                  ListTile(
                    leading: const Icon(Icons.qr_code_outlined),
                    title: const Text('Einladungscode'),
                    subtitle: SelectableText(inviteCode),
                  ),
                if (inviteCode != null) const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('WG wechseln'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showChangeFlatshareConfirmation(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'App',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dunkler Modus'),
                  subtitle: const Text('App in dunkler Farbe anzeigen'),
                  value: context.watch<NotificationPreferences>().isDarkMode,
                  onChanged: (value) {
                    context.read<NotificationPreferences>().setIsDarkMode(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Benachrichtigungen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Abmelden'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _logout(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Über diese App'),
                  subtitle: FutureBuilder<String>(
                    future: VersionCheckService.instance.currentVersion,
                    builder: (context, snapshot) {
                      final version = snapshot.data ?? '...';

                      return Text('Version $version');
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result =
                        await VersionCheckService.instance.checkForUpdates();

                    if (!context.mounted) return;

                    if (result.hasUpdate) {
                      UpdateAlertDialog.show(
                        context: context,
                        currentVersion: result.currentVersion,
                        latestVersion: result.latestVersion,
                        releaseUrl: result.releaseUrl,
                      );
                    } else {
                      final snackBar = SnackBar(
                        content: Text(
                          'Du hast die neueste Version '
                          '(${result.currentVersion}) installiert.',
                        ),
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, right: 8, bottom: 12),
                child: Text(
                  'Wer bist du?',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ...WGData.members.map((member) {
                final isSelected = WGData.currentMemberId == member.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: WGData.memberColor(member),
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(member.name),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  selected: isSelected,
                  onTap: () async {
                    await WGData.setCurrentMember(member.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_off_outlined),
                ),
                title: const Text('Keine Person'),
                trailing: WGData.currentMember == null
                    ? const Icon(Icons.check)
                    : null,
                selected: WGData.currentMember == null,
                onTap: () async {
                  await WGData.setCurrentMember(null);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
