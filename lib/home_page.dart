import 'package:flutter/material.dart';

import 'shopping_page.dart';
import 'task_page.dart';
import 'members_page.dart';
import 'wg_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WGData.version,
      builder: (context, _, child) {
        final currentMember = WGData.currentMember;

        return Scaffold(
          appBar: AppBar(title: const Text('Unsere WG')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentMember == null
                      ? 'Guten Abend'
                      : 'Guten Abend ${currentMember.name}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  currentMember == null ? 'Willkommen in unserer WG!' : '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Wer das liest ist gay',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,

                    // Slightly taller than wide.
                    childAspectRatio: 0.9,

                    children: [
                      // 🛒 Einkaufen
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShoppingPage(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Einkaufen',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text('0 offene Artikel'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ✅ Aufgaben
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TaskPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Aufgaben',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  WGData.currentMember == null
                                      ? 'Keine Person ausgewählt'
                                      : WGData.currentMemberTaskCount == 0
                                      ? 'Alles erledigt ✓'
                                      : '${WGData.currentMemberTaskCount} für dich',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 💬 Chat
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            // Chat kommt später.
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Chat',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text('Keine neuen Nachrichten'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 👥 Unsere WG
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MembersPage(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Unsere WG',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text('Bewohner'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
