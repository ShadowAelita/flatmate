import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wg_data.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final TextEditingController _controller = TextEditingController();

  bool _showCompleted = true;
  VoidCallback? _versionListener;
  bool _showSuggestions = false;
  final Set<String> _suggestionCache = {};

  @override
  void initState() {
    super.initState();

    _versionListener = () {
      if (mounted) setState(() {});
    };
    WGData.version.addListener(_versionListener!);

    _controller.addListener(_onTextChanged);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('shopping_suggestions') ?? [];
    setState(() {
      _suggestionCache
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _saveSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'shopping_suggestions', _suggestionCache.toList());
  }

  void _onTextChanged() {
    final text = _controller.text.trim().toLowerCase();

    if (text.isEmpty) {
      if (mounted) {
        setState(() => _showSuggestions = false);
      }
      return;
    }

    final suggestions = _suggestionCache
        .where((name) => name.toLowerCase().contains(text))
        .toList();

    if (mounted) {
      setState(() => _showSuggestions = suggestions.isNotEmpty);
    }
  }

  List<String> get _visibleSuggestions {
    final text = _controller.text.trim().toLowerCase();

    if (text.isEmpty) {
      return _suggestionCache.toList()..sort((a, b) => a.compareTo(b));
    }

    return _suggestionCache
        .where((name) => name.toLowerCase().contains(text))
        .toList()
      ..sort((a, b) => a.compareTo(b));
  }

  @override
  void dispose() {
    if (_versionListener != null) {
      WGData.version.removeListener(_versionListener!);
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final item = _controller.text.trim();

    if (item.isEmpty) {
      return;
    }

    try {
      await WGData.addShoppingItem(name: item, quantity: 1);

      _suggestionCache.add(item);
      await _saveSuggestions();

      _controller.clear();
      _showSuggestions = false;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not add shopping item: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einkauf konnte nicht hinzugefügt werden'),
          ),
        );
      }
    }
  }

  String? _getClaimedMemberName(Map<String, dynamic> item) {
    final claimedBy = item['claimedBy'];

    if (claimedBy == null) {
      return null;
    }

    for (final member in WGData.members) {
      if (member.id == claimedBy) {
        return member.name;
      }
    }

    return null;
  }

  void _toggleClaim(Map<String, dynamic> item) async {
    final currentMemberId = WGData.currentMemberId;

    if (currentMemberId == null) return;

    try {
      if (item['claimedBy'] == currentMemberId) {
        await WGData.updateShoppingItem(
          id: item['id'] as String,
          clearClaimedBy: true,
        );
      } else {
        await WGData.updateShoppingItem(
          id: item['id'] as String,
          claimedBy: currentMemberId,
        );
      }
    } catch (e) {
      debugPrint('Could not update shopping item claim: $e');
    }
  }

  Future<void> _editNote(Map<String, dynamic> item) async {
    final noteController =
        TextEditingController(text: item['note']?.toString() ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Notiz',
            hintText: 'z. B. Bio, 2% Fett...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, noteController.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    final trimmed = result;

    try {
      await WGData.updateShoppingItem(
        id: item['id'] as String,
        note: trimmed.isEmpty ? null : trimmed,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not update shopping item note: $e');
    }
  }

  void _duplicateItem(Map<String, dynamic> item) async {
    try {
      await WGData.duplicateShoppingItem(item);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Could not duplicate shopping item: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einkauf konnte nicht dupliziert werden'),
          ),
        );
      }
    }
  }

  Widget _buildShoppingItem(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  ) {
    final completed = item['completed'] as bool;
    final quantity = item['quantity'] as int;
    final claimedMember = _getClaimedMemberName(item);
    final claimed = claimedMember != null;
    final currentMemberId = WGData.currentMemberId;
    final claimedByCurrentUser = item['claimedBy'] == currentMemberId;

    final cardColor = completed
        ? Colors.green.withValues(alpha: 0.15)
        : claimed
        ? Colors.amber.withValues(alpha: 0.15)
        : null;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: completed,
              onChanged: (value) async {
                final completed = value ?? false;

                try {
                  await WGData.updateShoppingItem(
                    id: item['id'] as String,
                    completed: completed,
                  );

                  if (mounted) {
                    setState(() {});
                  }
                } catch (e) {
                  debugPrint('Could not update shopping item: $e');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Einkauf konnte nicht aktualisiert werden',
                        ),
                      ),
                    );
                  }
                }
              },
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      decoration: completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: completed
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),

                  if (item['note']?.toString().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item['note'].toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: quantity > 1
                            ? () async {
                                try {
                                  await WGData.updateShoppingItem(
                                    id: item['id'] as String,
                                    quantity: quantity - 1,
                                  );

                                  if (mounted) {
                                    setState(() {});
                                  }
                                } catch (e) {
                                  debugPrint('Could not decrease quantity: $e');
                                }
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                        tooltip: 'Weniger',
                      ),

                      Container(
                        width: 32,
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          try {
                            await WGData.updateShoppingItem(
                              id: item['id'] as String,
                              quantity: quantity + 1,
                            );

                            if (mounted) {
                              setState(() {});
                            }
                          } catch (e) {
                            debugPrint('Could not increase quantity: $e');
                          }
                        },
                        icon: const Icon(Icons.add),
                        tooltip: 'Mehr',
                      ),
                    ],
                  ),

                  TextButton.icon(
                    onPressed: () {
                      _toggleClaim(item);
                    },
                    style: claimedByCurrentUser
                        ? TextButton.styleFrom(
                            foregroundColor: Colors.amber)
                        : null,
                    icon: Icon(
                      claimedByCurrentUser
                          ? Icons.lock_outline
                          : claimed
                              ? Icons.lock_outline
                              : Icons.shopping_bag_outlined,
                      size: 18,
                      color: claimedByCurrentUser
                          ? Colors.amber
                          : claimed
                              ? WGData.memberColor(
                                  WGData.members.firstWhere(
                                    (member) =>
                                        member.id == item['claimedBy'],
                                  ),
                                )
                              : null,
                    ),
                    label: Text(
                      claimedByCurrentUser
                          ? 'Nicht mehr reserven'
                          : claimed
                              ? '$claimedMember kauft das'
                              : 'Ich kaufe das',
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _editNote(item),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Notiz bearbeiten',
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _duplicateItem(item),
              icon: const Icon(Icons.content_copy),
              tooltip: 'Duplizieren',
            ),
            IconButton(
              onPressed: () async {
                try {
                  await WGData.deleteShoppingItem(item['id'] as String);

                  if (mounted) {
                    setState(() {});
                  }
                } catch (e) {
                  debugPrint('Could not delete shopping item: $e');
                }
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingItemWithDismiss(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  ) {
    final itemId = item['id']?.toString() ?? index.toString();

    return Dismissible(
      key: ValueKey('shopping_$itemId'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        try {
          await WGData.deleteShoppingItem(item['id'] as String);
        } catch (e) {
          debugPrint('Could not delete shopping item: $e');
        }

        if (mounted) {
          setState(() {});
        }
      },
      child: _buildShoppingItem(context, item, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openItems = WGData.shoppingItems
        .where((item) => item['completed'] != true)
        .toList();

    final completedItems = WGData.shoppingItems
        .where((item) => item['completed'] == true)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Einkaufen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Was brauchen wir?',
                          hintText: 'z. B. Milch',
                          prefixIcon: Icon(Icons.shopping_cart_outlined),
                        ),
                        onSubmitted: (_) => _addItem(),
                        onTap: _onTextChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      tooltip: 'Hinzufügen',
                    ),
                  ],
                ),

                if (_showSuggestions && _visibleSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _visibleSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _visibleSuggestions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 16,
                          ),
                          title: Text(
                            suggestion,
                            style: const TextStyle(fontSize: 15),
                          ),
                          onTap: () {
                            _controller.text = suggestion;
                            _showSuggestions = false;
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Offen',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  if (openItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Keine offenen Einkäufe',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ...openItems.map(
                      (item) => _buildShoppingItemWithDismiss(
                        context,
                        item,
                        WGData.shoppingItems.indexOf(item),
                      ),
                    ),

                  const SizedBox(height: 8),

                  if (completedItems.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        initiallyExpanded: _showCompleted,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _showCompleted = expanded;
                          });
                        },
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text(
                          'Erledigt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${completedItems.length} '
                          '${completedItems.length == 1 ? 'Artikel' : 'Artikel'}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Column(
                              children: completedItems
                                  .map(
                                    (item) => _buildShoppingItem(
                                      context,
                                      item,
                                      WGData.shoppingItems.indexOf(item),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
