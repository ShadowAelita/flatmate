import 'package:flutter/material.dart';

import 'wg_data.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  String _unit = 'Stk';

  final List<String> _units = ['Stk', 'L', 'ml', 'kg', 'g', 'Pack'];

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_onVersionChanged);
    _nameController.dispose();
    _quantityController.dispose();
    _minController.dispose();
    super.dispose();
  }

  void _onVersionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final minQuantity = double.tryParse(_minController.text) ?? 0;

    await WGData.addInventoryItem(name, quantity, _unit, minQuantity);

    _nameController.clear();
    _quantityController.clear();
    _minController.clear();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateQuantity(String id, double delta) async {
    final index = WGData.inventoryItems.indexWhere(
      (item) => item['id']?.toString() == id,
    );

    if (index == -1) return;

    final currentValue = WGData.inventoryItems[index]['quantity'];
    final current = currentValue is double ? currentValue : (currentValue as num).toDouble();
    final newQuantity = (current + delta).clamp(0, double.infinity);

    await WGData.updateInventoryItem(id, quantity: newQuantity as double?);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteItem(String id) async {
    await WGData.deleteInventoryItem(id);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Haushaltsinventar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Artikel',
                      hintText: 'z. B. Toilettenpapier',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Menge',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _unit,
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _unit = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  tooltip: 'Hinzufügen',
                ),
              ],
            ),
          ),
          Expanded(
            child: WGData.inventoryItems.isEmpty
                ? Center(
                    child: Text(
                      'Keine Artikel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: WGData.inventoryItems.length,
                    itemBuilder: (context, index) {
                      final item = WGData.inventoryItems[index];
                      final quantity = item['quantity'] as double? ?? 0;
                      final minQuantity = item['min_quantity'] as double? ?? 0;
                      final isLow = quantity <= minQuantity && minQuantity > 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isLow
                            ? Colors.red.withValues(alpha: 0.1)
                            : null,
                        child: ListTile(
                          title: Text(item['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${quantity.toStringAsFixed(1)} ${item['unit']} · Mindestens ${minQuantity.toStringAsFixed(1)} ${item['unit']}',
                            style: TextStyle(
                              color: isLow ? Colors.red : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _updateQuantity(item['id'].toString(), -1),
                                icon: const Icon(Icons.remove),
                              ),
                              IconButton(
                                onPressed: () => _updateQuantity(item['id'].toString(), 1),
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                onPressed: () => _deleteItem(item['id'].toString()),
                                icon: const Icon(Icons.delete_outline),
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
    );
  }
}
