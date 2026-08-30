import 'package:flutter/material.dart';

import 'wg_data.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final TextEditingController _controller = TextEditingController();

  VoidCallback? _versionListener;

  @override
  void initState() {
    super.initState();

    _versionListener = () {
      if (mounted) setState(() {});
    };
    WGData.version.addListener(_versionListener!);
  }

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
              title: const Text('Farbe auswählen'),
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
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, selectedColorIndex);
                  },
                  child: const Text('Hinzufügen'),
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
            const SnackBar(content: Text('Bewohner konnte nicht aktualisiert werden')),
          );
      }
    }
  }

  Future<void> _deleteMember(WGMember member) async {
    try {
      await WGData.deleteMember(member.id);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not delete member: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bewohner konnte nicht gelöscht werden')));
    }
  }

  void _showFlatshareManagementDialog(BuildContext context) {
    final nameController =
        TextEditingController(text: WGData.householdName ?? 'Unsere WG');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Name der WG'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isNotEmpty) {
                  await WGData.updateHouseholdName(name);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = WGData.isAdmin;
    final householdName = WGData.householdName;
    final inviteCode = WGData.inviteCode;

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

            if (householdName != null || inviteCode != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    if (householdName != null)
                      ListTile(
                        leading: const Icon(Icons.home_work_outlined),
                        title: const Text('Name der WG'),
                        subtitle: Text(householdName),
                        trailing: isAdmin
                            ? const Icon(Icons.edit_outlined, size: 18)
                            : null,
                        onTap: isAdmin
                            ? () => _showFlatshareManagementDialog(context)
                            : null,
                      ),
                    if (householdName != null) const Divider(height: 1),
                    if (inviteCode != null)
                      ListTile(
                        leading: const Icon(Icons.qr_code_outlined),
                        title: const Text('Einladungscode'),
                        subtitle: SelectableText(
                          inviteCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        trailing: isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Neu generieren',
                                onPressed: () async {
                                  final success =
                                      await WGData.refreshInviteCode();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Neuer Einladungscode generiert'
                                              : 'Konnte keinen neuen '
                                                  'Einladungscode generieren',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              )
                            : null,
                      ),
                    if (inviteCode != null && isAdmin) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.share_outlined),
                        title: const Text('Einladen'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: SelectableText(
                                'Teile diesen Einladungscode '
                                'mit deinen Mitbewohnern: '
                                '$inviteCode',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],

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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
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
                              child: member.isAdmin
                                  ? const Icon(Icons.star, size: 20)
                                  : Text(
                                      member.name.isNotEmpty
                                          ? member.name[0].toUpperCase()
                                          : '?',
                                    ),
                            ),
                            title: Row(
                              children: [
                                Text(member.name),
                                if (member.isAdmin) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star,
                                      size: 16, color: Colors.yellow),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (WGData.currentMemberId == member.id)
                                  const Text('Du'),
                                if (isAdmin &&
                                    member.id !=
                                        WGData.currentMemberId)
                                  Text(
                                    member.isAdmin
                                        ? 'Administrator'
                                        : 'Kein Administrator',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: member.isAdmin
                                          ? Colors.yellow.shade700
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isAdmin
                                ? _buildAdminActions(context, member)
                                : const Icon(Icons.chevron_right),
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

  Widget _buildAdminActions(BuildContext context, WGMember member) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            member.isAdmin
                ? Icons.star
                : Icons.star_border,
            color: member.isAdmin ? Colors.yellow.shade700 : null,
            size: 20,
          ),
          tooltip: member.isAdmin
              ? 'Administrator entfernen'
              : 'Zur Administrator machen',
          onPressed: () async {
            await WGData.setAdmin(member.id, !member.isAdmin);
          },
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 18),
      ],
    );
  }

  @override
  void dispose() {
    if (_versionListener != null) {
      WGData.version.removeListener(_versionListener!);
    }
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

            if (WGData.isAdmin &&
                widget.member.id != WGData.currentMemberId)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
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

  const _EditMemberResult({this.name, this.colorIndex}) : delete = false;

  const _EditMemberResult.delete()
    : name = null,
      colorIndex = null,
      delete = true;
}
