import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WG',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const MyHomePage(title: 'Unsere WG'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Willkommen in unserer WG!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ShoppingPage()),
                  );
                },
                child: const ListTile(
                  leading: Icon(Icons.shopping_cart),
                  title: Text('Einkaufen'),
                  subtitle: Text('0 offene Artikel'),
                ),
              ),
            ),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TaskList()),
                  );
                },
                child: const ListTile(
                  leading: Icon(Icons.check_circle),
                  title: Text('Aufgaben'),
                  subtitle: Text('0 offene Aufgaben'),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Chat'),
                subtitle: const Text('Keine neuen Nachrichten'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                    decoration: const InputDecoration(
                      labelText: 'Was brauchen wir?',
                      border: OutlineInputBorder(),
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

                  return ListTile(
                    leading: Checkbox(
                      value: item['completed'],
                      onChanged: (value) {
                        setState(() {
                          item['completed'] = value;
                        });
                      },
                    ),

                    title: Text(
                      item['name'],
                      style: TextStyle(
                        decoration: item['completed']
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),

                    subtitle: Row(
                      children: [
                        IconButton(
                          onPressed: item['quantity'] > 1
                              ? () {
                                  setState(() {
                                    item['quantity']--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                          tooltip: 'Weniger',
                        ),

                        Text(
                          '${item['quantity']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        IconButton(
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

                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          _shoppingItems.removeAt(index);
                        });
                      },
                      icon: const Icon(Icons.delete),
                      tooltip: 'Löschen',
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

class TaskList extends StatelessWidget {
  const TaskList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: const Center(
        child: Text('Offene Aufgaben', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
