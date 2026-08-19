import 'package:flutter/material.dart';

import 'wg_data.dart';
import 'notification_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                backgroundColor: WGData.currentMember == null
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : WGData.memberColor(WGData.currentMember!),
                child: WGData.currentMember == null
                    ? const Icon(Icons.person_outline)
                    : Text(
                        WGData.currentMember!.name.isNotEmpty
                            ? WGData.currentMember!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              title: Text(
                WGData.currentMember?.name ?? 'Keine Person ausgewählt',
              ),
              subtitle: const Text('Wer bist du in dieser WG?'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showMemberPicker(context);
              },
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
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Benachrichtigungen'),
                  subtitle: const Text('Benachrichtigungseinstellungen'),
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
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Darstellung'),
                  subtitle: const Text('Kommt später'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Über diese App'),
                  subtitle: const Text('Flatmate'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
