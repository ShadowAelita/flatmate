import 'package:flutter/material.dart';

import 'wg_data.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _addTask() async {
    final task = _controller.text.trim();

    if (task.isEmpty) {
      return;
    }

    setState(() {
      WGData.tasks.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': task,
        'completed': false,
        'assignedTo': null,
        'dueDate': null,
      });
    });

    _controller.clear();

    await WGData.save();
  }

  String _formatDueDate(dynamic value) {
    if (value == null) {
      return 'Keine Frist';
    }

    final date = DateTime.tryParse(value as String);

    if (date == null) {
      return 'Keine Frist';
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final dueDay = DateTime(date.year, date.month, date.day);

    final difference = dueDay.difference(today).inDays;

    if (difference < 0) {
      return 'Überfällig';
    }

    if (difference == 0) {
      return 'Heute';
    }

    if (difference == 1) {
      return 'Morgen';
    }

    if (difference == 2) {
      return 'Übermorgen';
    }

    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _pickDueDate(Map<String, dynamic> task) async {
    final now = DateTime.now();

    final currentDate = task['dueDate'] != null
        ? DateTime.tryParse(task['dueDate'] as String)
        : null;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      task['dueDate'] = pickedDate.toIso8601String();
    });

    await WGData.save();
  }

  void _showAssignmentDialog(Map<String, dynamic> task) {
    if (WGData.members.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Keine Bewohner'),
            content: const Text(
              'Füge zuerst Bewohner unter "Unsere WG" hinzu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aufgabe zuweisen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('Niemanden zuweisen'),
                  onTap: () async {
                    setState(() {
                      task['assignedTo'] = null;
                    });

                    await WGData.save();

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),

                ...WGData.members.map(
                  (member) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: WGData.memberColor(member),
                      child: const Icon(Icons.person),
                    ),
                    title: Text(member.name),
                    onTap: () async {
                      setState(() {
                        task['assignedTo'] = member.id;
                      });

                      await WGData.save();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
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

  String? _getAssignedMemberName(Map<String, dynamic> task) {
    final assignedTo = task['assignedTo'];

    if (assignedTo == null) {
      return null;
    }

    for (final member in WGData.members) {
      if (member.id == assignedTo) {
        return member.name;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Was muss erledigt werden?',
                hintText: 'z. B. Küche putzen',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              onSubmitted: (_) => _addTask(),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: WGData.tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Keine offenen Aufgaben',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: WGData.tasks.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }

                        final task = WGData.tasks.removeAt(oldIndex);
                        WGData.tasks.insert(newIndex, task);

                        await WGData.save();
                      },
                      itemBuilder: (context, index) {
                        final task = WGData.tasks[index];
                        final completed = task['completed'] as bool;
                        final assignedMember = _getAssignedMemberName(task);

                        final cardColor = completed
                            ? Colors.green.withValues(alpha: 0.15)
                            : null;

                        return Card(
                          key: ValueKey(task['id']),
                          color: cardColor,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: completed,
                                  onChanged: (value) async {
                                    setState(() {
                                      task['completed'] = value ?? false;
                                    });

                                    await WGData.save();
                                  },
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['name'],
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          decoration: completed
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          color: completed
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                              : null,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () =>
                                            _showAssignmentDialog(task),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                assignedMember == null
                                                    ? Icons.person_outline
                                                    : Icons.person,
                                                size: 18,
                                                color: assignedMember == null
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                    : WGData.memberColor(
                                                        WGData.members.firstWhere(
                                                          (member) =>
                                                              member.id ==
                                                              task['assignedTo'],
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                assignedMember ??
                                                    'Nicht zugewiesen',
                                                style: TextStyle(
                                                  color: assignedMember == null
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _pickDueDate(task),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_outlined,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatDueDate(task['dueDate']),
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                IconButton(
                                  onPressed: () async {
                                    setState(() {
                                      WGData.tasks.removeAt(index);
                                    });

                                    await WGData.save();
                                  },
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
      ),
    );
  }
}
