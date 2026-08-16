import 'package:flutter/material.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _tasks = [];

  void _addTask() {
    final task = _controller.text.trim();

    if (task.isEmpty) {
      return;
    }

    setState(() {
      _tasks.add({'name': task, 'completed': false, 'assignedTo': null});
    });

    _controller.clear();
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
              child: _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Keine offenen Aufgaben',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final completed = task['completed'] as bool;

                        final cardColor = completed
                            ? Colors.green.withValues(alpha: 0.15)
                            : null;

                        return Card(
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
                                  onChanged: (value) {
                                    setState(() {
                                      task['completed'] = value ?? false;
                                    });
                                  },
                                ),

                                Expanded(
                                  child: Text(
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
                                ),

                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _tasks.removeAt(index);
                                    });
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
