import 'package:flutter/material.dart';

import 'wg_data.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final TextEditingController _controller = TextEditingController();

  void _addMember() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unsere WG')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                              onPressed: () {
                                setState(() {
                                  WGData.members.removeAt(index);
                                });
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
