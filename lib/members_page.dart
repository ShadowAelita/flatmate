import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                      backgroundColor: WGData.memberColor(member),
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
                      await WGData.setCurrentMember(member.id);

                      if (mounted) {
                        setState(() {});
                      }

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

    if (WGData.members.any(
      (member) => member.name.toLowerCase() == name.toLowerCase(),
    )) {
      return;
    }

    int selectedColorIndex = 0;

    final chosenColorIndex = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Choose your color'),
              content: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(WGData.memberColors.length, (index) {
                  final color = WGData.memberColors[index];
                  final selected = selectedColorIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColorIndex = index;
                      });
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: color,
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, selectedColorIndex);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosenColorIndex == null) {
      return;
    }

    try {
      await WGData.addMember(name: name, colorIndex: chosenColorIndex);

      _controller.clear();

      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('========== ADD MEMBER FAILED ==========');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=======================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _showEditMemberDialog(WGMember member) async {
    final result = await showDialog<_EditMemberResult>(
      context: context,
      builder: (context) {
        return _EditMemberDialog(member: member);
      },
    );

    if (result == null) {
      return;
    }

    if (result.delete) {
      await _deleteMember(member);
      return;
    }

    final newName = result.name!;
    final newColorIndex = result.colorIndex!;

    final duplicate = WGData.members.any(
      (existingMember) =>
          existingMember.id != member.id &&
          existingMember.name.toLowerCase() == newName.toLowerCase(),
    );

    if (duplicate) {
      return;
    }

    try {
      await WGData.updateMember(
        id: member.id,
        name: newName,
        colorIndex: newColorIndex,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to update member: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update member.')),
        );
      }
    }

    await WGData.save();
  }

  Future<void> _deleteMember(WGMember member) async {
    try {
      // Delete the member from Supabase first.
      await Supabase.instance.client
          .from('members')
          .delete()
          .eq('id', member.id);

      // Update local state after Supabase succeeds.
      setState(() {
        WGData.members.removeWhere(
          (existingMember) => existingMember.id == member.id,
        );

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

        WGData.chatMessages.removeWhere(
          (message) => message['senderId'] == member.id,
        );
      });

      // Keep local storage in sync too.
      await WGData.save();
    } catch (e) {
      debugPrint('Could not delete member: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete member')));
    }
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
                leading: CircleAvatar(
                  backgroundColor: WGData.currentMember == null
                      ? null
                      : WGData.memberColor(WGData.currentMember!),
                  child: const Icon(Icons.person),
                ),
                title: const Text('Aktiver Benutzer'),
                subtitle: Text(
                  WGData.currentMember?.name ?? 'Niemand ausgewählt',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCurrentUserDialog,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Knut',
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
                            leading: CircleAvatar(
                              backgroundColor: WGData.memberColor(member),
                              child: Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(member.name),
                            subtitle: WGData.currentMemberId == member.id
                                ? const Text('Du')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _showEditMemberDialog(member);
                            },
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _EditMemberDialog extends StatefulWidget {
  final WGMember member;

  const _EditMemberDialog({required this.member});

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final TextEditingController _nameController;
  late int _selectedColorIndex;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.member.name);

    _selectedColorIndex = widget.member.colorIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Profil bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Farbe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(WGData.memberColors.length, (index) {
                final color = WGData.memberColors[index];
                final selected = _selectedColorIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: color,
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Bewohner löschen',
                style: TextStyle(color: Colors.red),
              ),
              onTap: _requestDelete,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final newName = _nameController.text.trim();

            if (newName.isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              _EditMemberResult(name: newName, colorIndex: _selectedColorIndex),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  void _requestDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bewohner löschen?'),
          content: Text(
            'Möchtest du ${widget.member.name} wirklich aus der WG löschen?\n\n'
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

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.pop(context, _EditMemberResult.delete());
  }
}

class _EditMemberResult {
  final String? name;
  final int? colorIndex;
  final bool delete;

  const _EditMemberResult({this.name, this.colorIndex, this.delete = false});

  const _EditMemberResult.delete()
    : name = null,
      colorIndex = null,
      delete = true;
}
