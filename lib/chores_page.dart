import 'package:flutter/material.dart';

import 'wg_data.dart';

class ChoresPage extends StatefulWidget {
  const ChoresPage({super.key});

  @override
  State<ChoresPage> createState() => _ChoresPageState();
}

class _ChoresPageState extends State<ChoresPage> {
  final TextEditingController _nameController = TextEditingController();
  String _frequency = 'weekly';
  final List<String> _frequencies = ['daily', 'weekly', 'biweekly', 'monthly'];

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_onVersionChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onVersionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addChore() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) return;

    await WGData.addChore(name, _frequency);

    _nameController.clear();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _completeChore(String id) async {
    await WGData.completeChore(id);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteChore(String id) async {
    await WGData.deleteChore(id);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _rotateChores() async {
    await WGData.rotateChores();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _lotteryAssign() async {
    await WGData.lotteryAssignChores();

    if (mounted) {
      setState(() {});
    }
  }

  String _frequencyLabel(String value) {
    switch (value) {
      case 'daily':
        return 'Täglich';
      case 'weekly':
        return 'Wöchentlich';
      case 'biweekly':
        return '14-tägig';
      case 'monthly':
        return 'Monatlich';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMemberId = WGData.currentMemberId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Putzdienst'),
        actions: [
          if (WGData.chores.isNotEmpty && WGData.members.length > 1) ...[
            IconButton(
              onPressed: _lotteryAssign,
              icon: const Icon(Icons.casino),
              tooltip: 'Zufallsverteilung',
            ),
            IconButton(
              onPressed: _rotateChores,
              icon: const Icon(Icons.autorenew),
              tooltip: 'Rotieren',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Neue Aufgabe',
                      hintText: 'z. B. Küche putzen',
                    ),
                    onSubmitted: (_) => _addChore(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _frequency,
                  items: _frequencies
                      .map((f) => DropdownMenuItem(value: f, child: Text(_frequencyLabel(f))))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _frequency = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addChore,
                  icon: const Icon(Icons.add),
                  tooltip: 'Hinzufügen',
                ),
              ],
            ),
          ),
          Expanded(
            child: WGData.chores.isEmpty
                ? Center(
                    child: Text(
                      'Keine Putzdienste',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: WGData.chores.length,
                    itemBuilder: (context, index) {
                      final chore = WGData.chores[index];
                      final assignedTo = chore['assigned_to']?.toString();
                      final member = assignedTo == null
                          ? null
                          : WGData.members.firstWhere(
                              (m) => m.id == assignedTo,
                              orElse: () => WGMember(
                                id: '',
                                name: 'Unbekannt',
                                colorIndex: 0,
                              ),
                            );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: member != null && member.id.isNotEmpty
                                ? WGData.memberColor(member)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Text(
                              member != null && member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: member != null && member.id.isNotEmpty
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                          ),
                          title: Text(chore['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${_frequencyLabel(chore['frequency']?.toString() ?? 'weekly')} · ${member?.name ?? 'Nicht zugewiesen'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _completeChore(chore['id'].toString()),
                                icon: const Icon(Icons.check_circle_outline),
                                tooltip: 'Erledigt',
                              ),
                              IconButton(
                                onPressed: () => _deleteChore(chore['id'].toString()),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Löschen',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
