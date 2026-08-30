import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'kasse_stats_page.dart';
import 'wg_data.dart';

class KassePage extends StatefulWidget {
  const KassePage({super.key});

  @override
  State<KassePage> createState() => _KassePageState();
}

class _KassePageState extends State<KassePage> {
  void _versionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_versionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_versionChanged);
    super.dispose();
  }

  void _addExpense(BuildContext context) {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final newCategoryController = TextEditingController();
    int selectedMemberIndex = 0;
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ValueListenableBuilder<int>(
          valueListenable: WGData.version,
          builder: (context, _, child) {
            final categories = WGData.allExpenseCategories;

            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Neue Ausgabe',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                            hintText: 'z. B. Lebensmittel',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Betrag (€)',
                            hintText: 'z. B. 23.50',
                            prefixIcon: Icon(Icons.euro),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Kategorie',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.map((cat) {
                              final selected = selectedCategory == cat;

                              return ChoiceChip(
                                label: Text(cat),
                                selected: selected,
                                onSelected: (_) {
                                  setSheetState(() {
                                    selectedCategory = cat;
                                  });
                                },
                              );
                            }),
                            InputChip(
                              label: const Text('Neue Kategorie'),
                              avatar: const Icon(Icons.add, size: 16),
                              onPressed: () {
                                final newCat =
                                    newCategoryController.text.trim();

                                if (newCat.isEmpty ||
                                    categories.contains(newCat)) {
                                  return;
                                }

                                WGData.addExpenseCategory(newCat);

                                setSheetState(() {
                                  selectedCategory = newCat;
                                });

                                newCategoryController.clear();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: newCategoryController,
                          decoration: InputDecoration(
                            labelText: 'Neue Kategorie',
                            hintText: 'z. B. Tanken',
                            prefixIcon: const Icon(Icons.category),
                            border: const OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Von wem gezahlt?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children:
                              List.generate(WGData.members.length, (index) {
                            final member = WGData.members[index];
                            final selected = selectedMemberIndex == index;

                            return ChoiceChip(
                              avatar: CircleAvatar(
                                backgroundColor: WGData.memberColor(member),
                                child: Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              label: Text(member.name),
                              selected: selected,
                              onSelected: (_) {
                                setSheetState(() {
                                  selectedMemberIndex = index;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () async {
                            final description =
                                descriptionController.text.trim();
                            final amount =
                                double.tryParse(amountController.text) ?? 0;

                            if (description.isEmpty || amount <= 0) {
                              return;
                            }

                            final paidBy = WGData.members.isNotEmpty
                                ? WGData.members[selectedMemberIndex].id
                                : null;

                            await WGData.addExpense(
                              description: description,
                              amount: amount,
                              paidBy: paidBy,
                              category: selectedCategory,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Speichern'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = WGData.members;
    final total = WGData.totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WG-Kasse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistik',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KasseStatsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: total == 0 && WGData.expenses.isEmpty
          ? _buildEmptyState(context)
          : _buildContent(context, members, total),
      floatingActionButton: FloatingActionButton(
        onPressed: members.isNotEmpty
            ? () => _addExpense(context)
            : null,
        tooltip: 'Ausgabe hinzufügen',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Ausgaben',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tippe auf +, um eine Ausgabe hinzuzufügen.',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WGMember> members,
    double total,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTotalCard(context, total, members.length),
        const SizedBox(height: 16),
        if (total > 0) ...[
          _buildChartCard(context),
          const SizedBox(height: 16),
        ],
        _buildBalanceCard(context, members, total),
        const SizedBox(height: 16),
        _buildExpenseList(context),
      ],
    );
  }

  Widget _buildTotalCard(BuildContext context, double total, int memberCount) {
    final share = memberCount > 0 ? total / memberCount : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Gesamtausgaben',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '€${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (memberCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '€${share.toStringAsFixed(2)} pro Person',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    final dailyTotals = _groupExpensesByDay(WGData.expenses);

    if (dailyTotals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ausgaben über die Zeit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Keine Ausgaben vorhanden',
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedDates = dailyTotals.keys.toList()..sort();

    final maxY = () {
      var max = 0.0;

      for (final v in dailyTotals.values) {
        if (v > max) max = v;
      }

      return max > 0 ? max * 1.2 : 100.0;
    }();

    final spots = List.generate(sortedDates.length, (index) {
      final date = sortedDates[index];
      final amount = dailyTotals[date] ?? 0.0;

      return FlSpot(index.toDouble(), amount);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ausgaben über die Zeit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  maxY: maxY,
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(26),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= sortedDates.length) {
                            return const SizedBox.shrink();
                          }

                          final date = sortedDates[index];

                          return SideTitleWidget(
                            axisSide: AxisSide.bottom,
                            child: Text(
                              _formatDate(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '€${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 150),
                curve: Curves.linear,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    List<WGMember> members,
    double total,
  ) {
    final byMember = WGData.expensesByMember;
    final share = members.isNotEmpty ? total / members.length : 0.0;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Ausgleich',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...members.map((member) {
            final paid = byMember[member.id] ?? 0.0;
            final balance = paid - share;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: WGData.memberColor(member),
                child: Text(
                  member.name.isNotEmpty
                      ? member.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(member.name),
                  if (member.id == WGData.currentMemberId) ...[
                    const SizedBox(width: 8),
                    const Text('Du', style: TextStyle(fontSize: 12)),
                  ],
                ],
              ),
              trailing: Text(
                '${balance >= 0 ? '+' : ''}€${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: balance >= 0
                      ? Colors.green.shade400
                      : Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseList(BuildContext context) {
    final expenseList = WGData.expenses;

    if (expenseList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Keine Ausgaben vorhanden',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Ausgaben',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: expenseList.length,
            itemBuilder: (context, index) {
              final expense = expenseList[index];

              return Dismissible(
                key: ValueKey(expense['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await _confirmDelete(context, expense);
                },
                onDismissed: (direction) {
                  WGData.deleteExpense(expense['id']?.toString() ?? '');
                },
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(expense['description']?.toString() ?? ''),
                  subtitle: Builder(
                    builder: (context) {
                      final paidByName = _findMemberName(
                        expense['paidBy']?.toString(),
                      );

                      String line1 = paidByName != null
                          ? 'Von $paidByName'
                          : 'Unbekannt';

                      final category = expense['category']?.toString();

                      if (category != null && category.isNotEmpty) {
                        line1 += ' · $category';
                      }

                      return Text(
                        line1,
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '€${double.tryParse(expense['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Bearbeiten',
                        onPressed: () {
                          _editExpense(context, expense);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1             ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> expense,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ausgabe löschen?'),
          content: Text(
            'Bist du sicher, dass du "${expense['description']}" löschen möchtest?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
  }

  void _editExpense(
    BuildContext context,
    Map<String, dynamic> expense,
  ) {
    final descriptionController = TextEditingController(
      text: expense['description']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: expense['amount']?.toString() ?? '',
    );
     final categories = WGData.allExpenseCategories;
    String? selectedCategory = expense['category']?.toString();
    bool excludeFromBalance = expense['excludeFromBalance'] == true;

    if (selectedCategory != null && !categories.contains(selectedCategory)) {
      selectedCategory = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ausgabe bearbeiten',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'Betrag (€)',
                        prefixIcon: const Icon(Icons.euro),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (categories.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map<Widget>((cat) {
                          final selected = selectedCategory == cat;

                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCategory = cat;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      title: const Text('Von Ausgleich ausklammern'),
                      subtitle: const Text(
                        'Zählt nicht zur WG-Ausgleichs-Berechnung',
                      ),
                      value: excludeFromBalance,
                      onChanged: (value) {
                        setSheetState(() {
                          excludeFromBalance = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final description =
                                  descriptionController.text.trim();
                              final amount =
                                  double.tryParse(amountController.text) ?? 0;

                              if (description.isEmpty || amount <= 0) {
                                return;
                              }

                              await WGData.updateExpense(
                                id: expense['id']?.toString() ?? '',
                                description: description,
                                amount: amount,
                                category: selectedCategory,
                                excludeFromBalance: excludeFromBalance,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Speichern'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await WGData.deleteExpense(
                                expense['id']?.toString() ?? '',
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            icon: const Icon(Icons.delete),
                            label: const Text('Löschen'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Map<String, double> _groupExpensesByDay(
    List<Map<String, dynamic>> expenseList,
  ) {
    final result = <String, double>{};

    for (final e in expenseList) {
      final createdAt = e['createdAt']?.toString();

      if (createdAt == null) continue;

      final date = createdAt.substring(0, 10);

      final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;

      result[date] = (result[date] ?? 0.0) + amount;
    }

    return result;
  }

  static String _formatDate(String isoDate) {
    final parts = isoDate.split('-');

    if (parts.length != 3) return isoDate;

    final day = parts[2];
    final month = parts[1];

    return '$day.$month';
  }

  String? _findMemberName(String? id) {
    if (id == null) return null;

    for (final member in WGData.members) {
      if (member.id == id) {
        return member.name;
      }
    }

    return null;
  }
}
