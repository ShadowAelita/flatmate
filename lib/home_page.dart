import 'package:flutter/material.dart';

import 'shopping_page.dart';
import 'task_page.dart';
import 'members_page.dart';
import 'wg_data.dart';
import 'chat_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Color _taskDueDateColor(BuildContext context, Map<String, dynamic> task) {
    final value = task['dueDate'];

    if (value == null) {
      return Theme.of(context).colorScheme.onSurface;
    }

    final date = DateTime.tryParse(value as String);

    if (date == null) {
      return Theme.of(context).colorScheme.onSurface;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final dueDay = DateTime(date.year, date.month, date.day);

    final difference = dueDay.difference(today).inDays;

    if (difference < 0) {
      return Colors.red;
    }

    if (difference == 0) {
      return Colors.yellow.shade700;
    }

    if (difference == 1) {
      return Colors.green;
    }

    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WGData.version,
      builder: (context, _, child) {
        final currentMember = WGData.currentMember;

        final currentMemberTasks = WGData.currentMemberTasks.take(3).toList();

        final currentMemberShoppingItems = WGData.currentMemberShoppingItems
            .take(3)
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Unsere WG')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: currentMember == null
                          ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                          : WGData.memberColor(currentMember),
                      child: currentMember == null
                          ? const Icon(Icons.person_outline)
                          : Text(
                              currentMember.name.isNotEmpty
                                  ? currentMember.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentMember == null
                                      ? 'Guten Abend'
                                      : 'Guten Abend ${currentMember.name}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(width: 8),

                              IconButton(
                                tooltip: 'Einstellungen',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.settings_outlined),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            currentMember == null
                                ? 'Wer das liest ist gay'
                                : '${WGData.currentMemberTaskCount} Aufgaben · '
                                      '${WGData.currentMemberShoppingItemCount} Einkäufe für dich',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      // 🛒 Einkaufen
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShoppingPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart, size: 48),

                                const SizedBox(height: 16),

                                const Text(
                                  'Einkaufen',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Column(
                                  children: [
                                    Text(
                                      WGData.openShoppingItemCount == 0
                                          ? 'Alles eingekauft ✓'
                                          : '${WGData.openShoppingItemCount} offene Artikel',
                                    ),

                                    if (currentMemberShoppingItems
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),

                                      ...currentMemberShoppingItems.map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
                                          child: Text(
                                            '• ${item['name']} × ${item['quantity']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),

                                      if (WGData
                                              .currentMemberShoppingItemCount >
                                          3)
                                        Text(
                                          '+ ${WGData.currentMemberShoppingItemCount - 3} weitere',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ✅ Aufgaben
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TaskPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 48),

                                const SizedBox(height: 16),

                                const Text(
                                  'Aufgaben',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                if (currentMember == null)
                                  const Text('Keine Person ausgewählt')
                                else if (currentMemberTasks.isEmpty)
                                  const Text('Alles erledigt ✓')
                                else
                                  Column(
                                    children: currentMemberTasks.map((task) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          '• ${task['name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _taskDueDateColor(
                                              context,
                                              task,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 💬 Chat
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChatPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat, size: 48),

                                SizedBox(height: 16),

                                Text(
                                  'Chat',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 6),

                                Builder(
                                  builder: (context) {
                                    final message = WGData.latestChatMessage;

                                    if (message == null) {
                                      return const Text('Keine Nachrichten');
                                    }

                                    final senderId = message['senderId'];

                                    WGMember? sender;

                                    for (final member in WGData.members) {
                                      if (member.id == senderId) {
                                        sender = member;
                                        break;
                                      }
                                    }

                                    if (sender == null) {
                                      return const Text('Neue Nachricht');
                                    }

                                    final text = message['text'] as String;
                                    final edited = message['edited'] == true;

                                    return Text(
                                      '${sender.name}: $text${edited ? ' · bearbeitet' : ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 👥 Unsere WG
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MembersPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people, size: 48),

                                const SizedBox(height: 16),

                                const Text(
                                  'Unsere WG',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  WGData.memberCount == 1
                                      ? '1 Bewohner'
                                      : '${WGData.memberCount} Bewohner',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
