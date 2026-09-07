import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'shopping_page.dart';
import 'task_page.dart';
import 'members_page.dart';
import 'wg_data.dart';
import 'chat_page.dart';
import 'settings_page.dart';
import 'kasse_page.dart';
import 'inventory_page.dart';
import 'stats_easter_egg_page.dart';
import 'notifications/notification_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tapCount = 0;
  DateTime? _lastTap;

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

  Widget _buildCard(String cardId, {required List<Map<String, dynamic>> currentMemberTasks, required List<Map<String, dynamic>> currentMemberShoppingItems}) {
    switch (cardId) {
      case 'shopping':
        return _buildShoppingCard(currentMemberShoppingItems);
      case 'inventory':
        return _buildInventoryCard();
      case 'tasks':
        return _buildTasksCard(currentMemberTasks);
      case 'chat':
        return _buildChatCard();
      case 'balance':
        return _buildBalanceCard();
      case 'members':
        return _buildMembersCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildShoppingCard(List<Map<String, dynamic>> currentMemberShoppingItems) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart, size: 48),
              const SizedBox(height: 16),
              const Text('Einkaufen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Column(
                children: [
                  Text(WGData.openShoppingItemCount == 0 ? 'Alles eingekauft ✓' : '${WGData.openShoppingItemCount} offene Artikel'),
                  if (currentMemberShoppingItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...currentMemberShoppingItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• ${item['name']} × ${item['quantity']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    )),
                    if (WGData.currentMemberShoppingItemCount > 4)
                      Text('+ ${WGData.currentMemberShoppingItemCount - 3} weitere', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksCard(List<Map<String, dynamic>> currentMemberTasks) {
    final currentMember = WGData.currentMember;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 48),
              const SizedBox(height: 16),
              const Text('Aufgaben', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (currentMember == null)
                const Text('Keine Person ausgewählt')
              else if (currentMemberTasks.isEmpty)
                const Text('Alles erledigt ✓')
              else
                Column(children: currentMemberTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${task['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: _taskDueDateColor(context, task))),
                )).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat, size: 48),
              const SizedBox(height: 16),
              const Text('Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final message = WGData.latestChatMessage;
                  if (message == null) return const Text('Keine Nachrichten');

                  final senderId = message['senderId'];
                  WGMember? sender;
                  for (final member in WGData.members) {
                    if (member.id == senderId) {
                      sender = member;
                      break;
                    }
                  }
                  if (sender == null) return const Text('Neue Nachricht');

                  final text = message['text'] as String;
                  final edited = message['edited'] == true;
                  final unreadCount = WGData.unreadMessageCount;

                  if (unreadCount > 0) {
                    return Column(children: [
                      Text('${sender.name}: $text${edited ? ' · bearbeitet' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('$unreadCount neue Nachricht${unreadCount == 1 ? '' : 'en'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.center),
                    ]);
                  }
                  return Text('${sender.name}: $text${edited ? ' · bearbeitet' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const KassePage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 48),
              const SizedBox(height: 16),
              const Text('WG-Kasse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final balance = WGData.currentMemberBalance;
                  if (balance == 0) return const Text('Ausgeglichen', style: TextStyle(fontSize: 13));
                  return Text('${balance > 0 ? "+" : ""}€${balance.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: balance > 0 ? Colors.green : Colors.red));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MembersPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people, size: 48),
              const SizedBox(height: 16),
              Text(WGData.householdName ?? 'Unsere WG', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(WGData.memberCount == 1 ? '1 Bewohner' : '${WGData.memberCount} Bewohner'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard() {
    final lowItems = WGData.inventoryItems.where((item) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
      final minQuantity = (item['min_quantity'] as num?)?.toDouble() ?? 0;
      return quantity <= minQuantity && minQuantity > 0;
    }).toList();

    final itemCount = WGData.inventoryItems.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2,
                size: 48,
                color: lowItems.isNotEmpty ? Colors.red : null,
              ),
              const SizedBox(height: 16),
              const Text('Inventar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (lowItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${lowItems.length} niedrig!',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                '$itemCount ${itemCount == 1 ? 'Artikel' : 'Artikel'}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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
          appBar: AppBar(
            title: Text(WGData.householdName ?? 'Unsere WG'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                     GestureDetector(
                        onTap: () {
                          final now = DateTime.now();

                          if (_lastTap == null ||
                              now.difference(_lastTap!).inSeconds > 3) {
                            _tapCount = 1;
                          } else {
                            _tapCount++;
                          }

                          _lastTap = now;

                          if (_tapCount >= 7) {
                            _tapCount = 0;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatsEasterEggPage(),
                              ),
                            );
                          }
                        },
                        child: CircleAvatar(
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
                                      ? 'Wilkommen'
                                      : 'Wilkommen ${currentMember.name}',
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
                                ? 'Kein Profil ausgewählt'
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
                  child: Consumer<NotificationPreferences>(
                    builder: (context, prefs, _) {
                      final visibleCards = prefs.dashboardCards
                          .where((c) => c.isVisible)
                          .toList();

                      if (visibleCards.isEmpty) {
                        return const Center(
                          child: Text('Keine Karten ausgewählt.\nPasst die Ansicht in den Einstellungen an.'),
                        );
                      }

                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: visibleCards.length,
                        itemBuilder: (context, index) {
                          return _buildCard(
                            visibleCards[index].id,
                            currentMemberTasks: currentMemberTasks,
                            currentMemberShoppingItems: currentMemberShoppingItems,
                          );
                        },
                      );
                    },
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
