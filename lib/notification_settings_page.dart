import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notifications/notification_preferences.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<NotificationPreferences>();

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Aufgaben',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Aufgaben-Zuweisungen'),
                  subtitle: const Text(
                    'Benachrichtigungen, wenn dir eine Aufgabe zugewiesen wird',
                  ),
                  value: preferences.taskAssignments,
                  onChanged: preferences.setTaskAssignments,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Aufgabe heute fällig'),
                  subtitle: const Text(
                    'Erinnerung am Tag, an dem eine Aufgabe fällig ist',
                  ),
                  value: preferences.taskDueToday,
                  onChanged: preferences.setTaskDueToday,
                ),
              ],
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
                SwitchListTile(
                  title: const Text('Einkaufsliste'),
                  subtitle: const Text(
                    'Benachrichtigungen über Änderungen an der Einkaufsliste',
                  ),
                  value: preferences.shopping,
                  onChanged: preferences.setShopping,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Chat'),
                  subtitle: const Text(
                    'Benachrichtigungen über neue Chat-Nachrichten',
                  ),
                  value: preferences.chat,
                  onChanged: preferences.setChat,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Allgemein'),
                  subtitle: const Text(
                    'Sonstige Benachrichtigungen von Flatmate',
                  ),
                  value: preferences.general,
                  onChanged: preferences.setGeneral,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
