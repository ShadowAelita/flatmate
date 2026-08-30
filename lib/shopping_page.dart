import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();

    _versionListener = () {
      if (mounted) setState(() {});
    };
    WGData.version.addListener(_versionListener!);
  }

  @override
  void dispose() {
    if (_versionListener != null) {
      WGData.version.removeListener(_versionListener!);
    }
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

      _controller.clear();

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
          claimedBy: null,
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
                      (item) => _buildShoppingItem(
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
