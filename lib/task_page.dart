import 'package:flutter/material.dart';

import 'notifications/notification_preferences.dart';
import 'notifications/notification_service.dart';
import 'wg_data.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TextEditingController _controller = TextEditingController();
  final NotificationPreferences _notificationPreferences =
      NotificationPreferences();
  @override
  void initState() {
    super.initState();
    _notificationPreferences.initialize();
  }

  Future<void> _addTask() async {
    final task = _controller.text.trim();

    if (task.isEmpty) {
      return;
    }

    try {
      final addedTask = await WGData.addTask(name: task);

      if (addedTask != null) {
        await _scheduleTaskNotification(addedTask);
      }

      _controller.clear();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not add task: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aufgabe konnte nicht hinzugefügt werden'),
          ),
        );
      }
    }
  }

  Future<void> _scheduleTaskNotification(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString();
    final taskName = task['name']?.toString();
    final dueDateValue = task['dueDate'];

    if (taskId == null || taskName == null || dueDateValue == null) {
      return;
    }

    final dueDate = DateTime.tryParse(dueDateValue.toString());

    if (dueDate == null) {
      return;
    }

    await _notificationPreferences.initialize();

    await NotificationService.instance.scheduleTaskDueToday(
      taskId: taskId,
      taskName: taskName,
      dueDate: dueDate,
      preferences: _notificationPreferences,
    );
  }

  Future<void> _sortTasksByDueDate() async {
    setState(() {
      WGData.tasks.sort((a, b) {
        final aValue = a['dueDate'];
        final bValue = b['dueDate'];

        if (aValue == null && bValue == null) {
          return 0;
        }

        if (aValue == null) {
          return 1;
        }

        if (bValue == null) {
          return -1;
        }

        final aDate = DateTime.tryParse(aValue.toString());
        final bDate = DateTime.tryParse(bValue.toString());

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return aDate.compareTo(bDate);
      });

      for (var index = 0; index < WGData.tasks.length; index++) {
        WGData.tasks[index]['sortOrder'] = index;
      }
    });

    await WGData.updateTaskOrder();
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

  Color _dueDateColor(BuildContext context, dynamic value) {
    if (value == null) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }

    final date = DateTime.tryParse(value as String);

    if (date == null) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
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

    return Theme.of(context).colorScheme.onSurfaceVariant;
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

    final dueDate = pickedDate.toIso8601String();

    try {
      // Remove any notification scheduled for the old due date.
      await NotificationService.instance.cancelTaskNotification(
        task['id'].toString(),
      );

      await WGData.updateTask(
        id: task['id'],
        dueDate: dueDate,
        updateDueDate: true,
      );

      // Schedule the notification for the new due date.
      await NotificationService.instance.scheduleTaskDueToday(
        taskId: task['id'].toString(),
        taskName: task['name']?.toString() ?? 'Aufgabe',
        dueDate: pickedDate,
        preferences: _notificationPreferences,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not update task due date: $e');
    }
  }

  Future<void> _pickRepeat(Map<String, dynamic> task) async {
    final selectedRepeat = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final currentRepeat = task['repeat'] ?? 'none';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Wiederholung',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Keine Wiederholung'),
                trailing: currentRepeat == 'none'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, 'none');
                },
              ),

              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('Täglich'),
                trailing: currentRepeat == 'daily'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, 'daily');
                },
              ),

              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Wöchentlich'),
                trailing: currentRepeat == 'weekly'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, 'weekly');
                },
              ),

              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Monatlich'),
                trailing: currentRepeat == 'monthly'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, 'monthly');
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedRepeat == null) {
      return;
    }

    try {
      await WGData.updateTask(id: task['id'], repeat: selectedRepeat);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not update task repeat: $e');
    }
  }

  DateTime? _getNextRepeatDate(dynamic dueDate, String repeat) {
    if (dueDate == null) {
      return null;
    }

    final currentDate = DateTime.tryParse(dueDate as String);

    if (currentDate == null) {
      return null;
    }

    switch (repeat) {
      case 'daily':
        return currentDate.add(const Duration(days: 1));

      case 'weekly':
        return currentDate.add(const Duration(days: 7));

      case 'monthly':
        final nextMonth = currentDate.month == 12
            ? DateTime(currentDate.year + 1, 1, 1)
            : DateTime(currentDate.year, currentDate.month + 1, 1);

        final lastDayOfNextMonth = DateTime(
          nextMonth.year,
          nextMonth.month + 1,
          0,
        ).day;

        final day = currentDate.day > lastDayOfNextMonth
            ? lastDayOfNextMonth
            : currentDate.day;

        return DateTime(nextMonth.year, nextMonth.month, day);

      default:
        return null;
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task, bool completed) async {
    try {
      await WGData.updateTask(id: task['id'], completed: completed);

      if (completed) {
        await NotificationService.instance.cancelTaskNotification(
          task['id'].toString(),
        );
      }

      if (!completed) {
        await _scheduleTaskNotification(task);

        if (mounted) {
          setState(() {});
        }

        return;
      }
      final repeat = task['repeat'] ?? 'none';

      if (repeat != 'none' && task['dueDate'] != null) {
        final nextDueDate = _getNextRepeatDate(task['dueDate'], repeat);

        if (nextDueDate != null) {
          final newTask = await WGData.addTask(
            name: task['name'],
            assignedTo: task['assignedTo'],
            dueDate: nextDueDate.toIso8601String(),
            repeat: repeat,
          );

          if (newTask != null) {
            await _scheduleTaskNotification(newTask);
          }
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not complete task: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aufgabe konnte nicht aktualisiert werden'),
          ),
        );
      }
    }
  }

  void _showAssignmentDialog(Map<String, dynamic> task) {
    if (WGData.members.isEmpty) {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Keine Bewohner'),
            content: const Text(
              'Füge zuerst Bewohner unter "Unsere WG" hinzu.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
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
      builder: (sheetContext) {
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
                  trailing: task['assignedTo'] == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    try {
                      await WGData.updateTask(
                        id: task['id'],
                        assignedTo: null,
                        updateAssignedTo: true,
                      );

                      if (mounted) {
                        setState(() {});
                      }

                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    } catch (e) {
                      debugPrint('Could not unassign task: $e');
                    }
                  },
                ),

                ...WGData.members.map((member) {
                  final selected = task['assignedTo'] == member.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: WGData.memberColor(member),
                      child: const Icon(Icons.person),
                    ),
                    title: Text(member.name),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () async {
                      try {
                        await WGData.updateTask(
                          id: task['id'],
                          assignedTo: member.id,
                          updateAssignedTo: true,
                        );

                        if (mounted) {
                          setState(() {});
                        }

                        // IMPORTANT:
                        // Only close the bottom sheet.
                        // Do not navigate away from TaskPage.
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      } catch (e) {
                        debugPrint('Could not assign task: $e');
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  WGMember? _getAssignedMember(Map<String, dynamic> task) {
    final assignedTo = task['assignedTo'];

    if (assignedTo == null) {
      return null;
    }

    for (final member in WGData.members) {
      if (member.id == assignedTo) {
        return member;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgaben'),
        actions: [
          IconButton(
            onPressed: _sortTasksByDueDate,
            icon: const Icon(Icons.sort),
            tooltip: 'Nach Frist sortieren',
          ),
        ],
      ),

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

                      onReorderItem: (oldIndex, newIndex) async {
                        onReorderItem:
                        (oldIndex, newIndex) async {
                          final task = WGData.tasks.removeAt(oldIndex);

                          WGData.tasks.insert(newIndex, task);

                          await WGData.updateTaskOrder();
                        };
                        final task = WGData.tasks.removeAt(oldIndex);

                        WGData.tasks.insert(newIndex, task);

                        await WGData.updateTaskOrder();
                      },

                      itemBuilder: (context, index) {
                        final task = WGData.tasks[index];

                        final completed = task['completed'] as bool;

                        final assignedMember = _getAssignedMember(task);

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
                                    await _completeTask(task, value ?? false);
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

                                      // Assignment
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
                                                        assignedMember,
                                                      ),
                                              ),

                                              const SizedBox(width: 6),

                                              Text(
                                                assignedMember?.name ??
                                                    'Nicht zugewiesen',
                                                style: TextStyle(
                                                  color: assignedMember == null
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                      : WGData.memberColor(
                                                          assignedMember,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Due date
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: () => _pickDueDate(task),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .calendar_today_outlined,
                                                    size: 18,
                                                    color: _dueDateColor(
                                                      context,
                                                      task['dueDate'],
                                                    ),
                                                  ),

                                                  const SizedBox(width: 6),

                                                  Text(
                                                    _formatDueDate(
                                                      task['dueDate'],
                                                    ),
                                                    style: TextStyle(
                                                      color: _dueDateColor(
                                                        context,
                                                        task['dueDate'],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          if (task['dueDate'] != null)
                                            IconButton(
                                              onPressed: () async {
                                                try {
                                                  await WGData.updateTask(
                                                    id: task['id'],
                                                    dueDate: null,
                                                    updateDueDate: true,
                                                  );
                                                  await NotificationService
                                                      .instance
                                                      .cancelTaskNotification(
                                                        task['id'].toString(),
                                                      );

                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                } catch (e) {
                                                  debugPrint(
                                                    'Could not remove task due date: $e',
                                                  );

                                                  if (!context.mounted) {
                                                    return;
                                                  }

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Frist konnte nicht entfernt werden',
                                                          ),
                                                        ),
                                                      );
                                                }
                                              },
                                              icon: const Icon(Icons.close),
                                              iconSize: 18,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              tooltip: 'Frist entfernen',
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // Repeat
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _pickRepeat(task),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.repeat,
                                                size: 18,
                                                color:
                                                    task['repeat'] != null &&
                                                        task['repeat'] != 'none'
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),

                                              const SizedBox(width: 6),

                                              Text(
                                                task['repeat'] == 'daily'
                                                    ? 'Täglich'
                                                    : task['repeat'] == 'weekly'
                                                    ? 'Wöchentlich'
                                                    : task['repeat'] ==
                                                          'monthly'
                                                    ? 'Monatlich'
                                                    : 'Keine Wiederholung',
                                                style: TextStyle(
                                                  color:
                                                      task['repeat'] != null &&
                                                          task['repeat'] !=
                                                              'none'
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                      : Theme.of(context)
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
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );

                                    try {
                                      await WGData.deleteTask(task['id']);

                                      if (mounted) {
                                        setState(() {});
                                      }
                                    } catch (e) {
                                      debugPrint('Could not delete task: $e');

                                      if (mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Aufgabe konnte nicht gelöscht werden',
                                            ),
                                          ),
                                        );
                                      }
                                    }
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
