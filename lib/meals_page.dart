import 'package:flutter/material.dart';

import 'wg_data.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _recipeController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_onVersionChanged);
    _nameController.dispose();
    _recipeController.dispose();
    super.dispose();
  }

  void _onVersionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addMeal() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) return;

    await WGData.addMeal(name, _recipeController.text.trim());

    _nameController.clear();
    _recipeController.clear();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteMeal(String id) async {
    await WGData.deleteMeal(id);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Essensplaner')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Gericht',
                    hintText: 'z. B. Spaghetti Bolognese',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipeController,
                  decoration: const InputDecoration(
                    labelText: 'Rezept',
                    hintText: 'Zutaten und Zubereitung...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _addMeal,
                  child: const Text('Hinzufügen'),
                ),
              ],
            ),
          ),
          Expanded(
            child: WGData.meals.isEmpty
                ? Center(
                    child: Text(
                      'Keine Gerichte',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: WGData.meals.length,
                    itemBuilder: (context, index) {
                      final meal = WGData.meals[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(meal['name']?.toString() ?? ''),
                          trailing: IconButton(
                            onPressed: () => _deleteMeal(meal['id'].toString()),
                            icon: const Icon(Icons.delete_outline),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(meal['recipe']?.toString() ?? 'Kein Rezept'),
                            ),
                          ],
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
