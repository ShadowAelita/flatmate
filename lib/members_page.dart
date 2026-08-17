import 'package:flutter/material.dart';

import 'wg_data.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final TextEditingController _controller = TextEditingController();
  void _showCurrentUserDialog() {
    if (WGData.members.isEmpty) {
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
                  'Wer bist du?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ...WGData.members.map(
                  (member) => ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(member.name),
                    trailing: WGData.currentMemberId == member.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () async {
                      setState(() {
                        WGData.currentMemberId = member.id;
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

  Future<void> _addMember() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    if (WGData.members.any((member) => member.name == name)) {
      return;
    }

    setState(() {
      WGData.members.add(
        WGMember(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
        ),
      );
    });

    _controller.clear();

    await WGData.save();

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unsere WG')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('Aktiver Benutzer'),
                subtitle: Text(
                  WGData.currentMember?.name ?? 'Niemand ausgewählt',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showCurrentUserDialog();
                },
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Louis',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onSubmitted: (_) => _addMember(),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: WGData.members.isEmpty
                  ? Center(
                      child: Text(
                        'Noch keine Bewohner hinzugefügt',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: WGData.members.length,
                      itemBuilder: (context, index) {
                        final member = WGData.members[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(member.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Löschen',
                              onPressed: () async {
                                final member = WGData.members[index];

                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Bewohner löschen?'),
                                      content: Text(
                                        'Möchtest du ${member.name} wirklich aus der WG löschen?\n\n'
                                        'Zugewiesene Aufgaben und Reservierungen werden freigegeben.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },
                                          child: const Text('Abbrechen'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },
                                          child: const Text('Löschen'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmed != true) {
                                  return;
                                }

                                setState(() {
                                  WGData.members.removeAt(index);

                                  if (WGData.currentMemberId == member.id) {
                                    WGData.currentMemberId = null;
                                  }

                                  for (final task in WGData.tasks) {
                                    if (task['assignedTo'] == member.id) {
                                      task['assignedTo'] = null;
                                    }
                                  }

                                  for (final item in WGData.shoppingItems) {
                                    if (item['claimedBy'] == member.id) {
                                      item['claimedBy'] = null;
                                    }
                                  }
                                });

                                await WGData.save();
                              },
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
