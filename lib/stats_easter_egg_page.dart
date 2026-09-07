import 'package:flutter/material.dart';

import 'wg_data.dart';

class StatsEasterEggPage extends StatefulWidget {
  const StatsEasterEggPage({super.key});

  @override
  State<StatsEasterEggPage> createState() => _StatsEasterEggPageState();
}

class _StatsEasterEggPageState extends State<StatsEasterEggPage> {
  @override
  Widget build(BuildContext context) {
    final totalTasks = WGData.tasks.length;
    final completedTasks = WGData.tasks.where((t) => t['completed'] == true).length;
    final totalShopping = WGData.shoppingItems.length;
    final completedShopping = WGData.shoppingItems.where((s) => s['completed'] == true).length;
    final totalExpenses = WGData.totalExpenses;
    final totalChores = WGData.chores.length;
    final totalMeals = WGData.meals.length;
    final totalPolls = WGData.polls.length;

    final memberStats = WGData.members.map((member) {
      final memberTasks = WGData.tasks.where((t) => t['assignedTo']?.toString() == member.id).length;
      final memberExpenses = WGData.expensesByMember[member.id] ?? 0.0;
      final memberShopping = WGData.shoppingItems.where((s) => s['claimedBy']?.toString() == member.id).length;

      return {
        'member': member,
        'tasks': memberTasks,
        'expenses': memberExpenses,
        'shopping': memberShopping,
      };
    }).toList();

    memberStats.sort((a, b) => (b['expenses'] as double).compareTo(a['expenses'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('WG Statistiken'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gesamtaktivität',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _StatRow('Aufgaben erledigt', '$completedTasks / $totalTasks'),
                  _StatRow('Einkäufe erledigt', '$completedShopping / $totalShopping'),
                  _StatRow('Ausgaben gesamt', '€${totalExpenses.toStringAsFixed(2)}'),
                  _StatRow('Putzdienste', '$totalChores'),
                  _StatRow('Gerichte', '$totalMeals'),
                  _StatRow('Umfragen', '$totalPolls'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mitglieder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...memberStats.map((stat) {
                    final member = stat['member'] as WGMember;
                    final tasks = stat['tasks'] as int;
                    final expenses = stat['expenses'] as double;
                    final shopping = stat['shopping'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: WGData.memberColor(member),
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '$tasks Aufgaben · $shopping Einkäufe',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '€${expenses.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (WGData.chores.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Putzdienst-Rotation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...WGData.chores.map((chore) {
                      final assignedTo = chore['assigned_to']?.toString();
                      final member = assignedTo == null
                          ? null
                          : WGData.members.firstWhere(
                              (m) => m.id == assignedTo,
                              orElse: () => WGMember(id: '', name: 'Unbekannt', colorIndex: 0),
                            );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(chore['name']?.toString() ?? ''),
                            ),
                            if (member != null && member.id.isNotEmpty)
                              CircleAvatar(
                                backgroundColor: WGData.memberColor(member),
                                radius: 12,
                                child: Text(
                                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
