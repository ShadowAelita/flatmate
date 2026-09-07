import 'package:flutter/material.dart';

import 'wg_data.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  void _search() {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() {
      _results = WGData.search(query);
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'shopping':
        return Icons.shopping_cart_outlined;
      case 'chat':
        return Icons.chat_outlined;
      case 'expense':
        return Icons.receipt_long_outlined;
      default:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Suche nach Aufgaben, Einkäufen, Chat oder Ausgaben',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _search(),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.trim().isEmpty
                          ? 'Gib einen Suchbegriff ein'
                          : 'Keine Ergebnisse',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];

                      return ListTile(
                        leading: Icon(_iconForType(result['type'])),
                        title: Text(result['title']?.toString() ?? ''),
                        subtitle: Text(result['subtitle']?.toString() ?? ''),
                        onTap: () {
                          // TODO: navigate to detail view based on type
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
