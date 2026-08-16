import 'package:flutter/material.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _shoppingItems = [];

  void _addItem() {
    final item = _controller.text.trim();

    if (item.isEmpty) {
      return;
    }

    setState(() {
      _shoppingItems.add({'name': item, 'completed': false, 'quantity': 1});
    });

    _controller.clear();
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
                itemCount: _shoppingItems.length,
                itemBuilder: (context, index) {
                  final item = _shoppingItems[index];
                  final completed = item['completed'] as bool;
                  final quantity = item['quantity'] as int;

                  return Card(
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
                                item['completed'] = value ?? false;
                              });
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
                                          ? () {
                                              setState(() {
                                                item['quantity']--;
                                              });
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
                                      onPressed: () {
                                        setState(() {
                                          item['quantity']++;
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Mehr',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              setState(() {
                                _shoppingItems.removeAt(index);
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
