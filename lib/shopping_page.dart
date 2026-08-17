import 'package:flutter/material.dart';

import 'wg_data.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _addItem() async {
    final item = _controller.text.trim();

    if (item.isEmpty) {
      return;
    }

    setState(() {
      WGData.shoppingItems.add({
        'name': item,
        'completed': false,
        'quantity': 1,
        'claimedBy': null,
      });
    });

    _controller.clear();
    await WGData.save();
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

  void _showClaimDialog(Map<String, dynamic> item) {
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
                  'Wer kauft das?',
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
                    trailing: item['claimedBy'] == member.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () async {
                      setState(() {
                        item['claimedBy'] = member.id;
                      });

                      await WGData.save();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: const Text('Reservierung aufheben'),
                  onTap: () async {
                    setState(() {
                      item['claimedBy'] = null;
                    });

                    await WGData.save();

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: ListView.builder(
                itemCount: WGData.shoppingItems.length,
                itemBuilder: (context, index) {
                  final item = WGData.shoppingItems[index];
                  final completed = item['completed'] as bool;
                  final quantity = item['quantity'] as int;
                  final claimedMember = _getClaimedMemberName(item);
                  final claimed = claimedMember != null;

                  final cardColor = completed
                      ? Colors.green.withValues(alpha: 0.15)
                      : claimed
                      ? Colors.amber.withValues(alpha: 0.15)
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
                            onChanged: (value) async {
                              setState(() {
                                item['completed'] = value ?? false;
                              });

                              await WGData.save();
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
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
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
                                              setState(() {
                                                item['quantity']--;
                                              });

                                              await WGData.save();
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
                                        setState(() {
                                          item['quantity']++;
                                        });

                                        await WGData.save();
                                      },
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Mehr',
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    _showClaimDialog(item);
                                  },
                                  style: claimed
                                      ? TextButton.styleFrom(
                                          foregroundColor: Colors.amber,
                                        )
                                      : null,
                                  icon: Icon(
                                    claimed
                                        ? Icons.lock_outline
                                        : Icons.shopping_bag_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    claimed
                                        ? '$claimedMember kauft das'
                                        : 'Ich kaufe das',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () async {
                              setState(() {
                                WGData.shoppingItems.removeAt(index);
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
