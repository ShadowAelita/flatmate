import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'wg_data.dart';

enum TimeFrame { week, month, year }

extension TimeFrameLabel on TimeFrame {
  String get label {
    switch (this) {
      case TimeFrame.week:
        return 'Woche';
      case TimeFrame.month:
        return 'Monat';
      case TimeFrame.year:
        return 'Jahr';
    }
  }
}

class KasseStatsPage extends StatefulWidget {
  const KasseStatsPage({super.key});

  @override
  State<KasseStatsPage> createState() => _KasseStatsPageState();
}

class _KasseStatsPageState extends State<KasseStatsPage> {
  TimeFrame _selectedTimeFrame = TimeFrame.month;

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_onVersionChanged);
    super.dispose();
  }

  void _onVersionChanged() {
    if (mounted) setState(() {});
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();

    switch (_selectedTimeFrame) {
      case TimeFrame.week:
        final start = now.subtract(const Duration(days: 6));

        final startOfDay = DateTime(start.year, start.month, start.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        return DateTimeRange(start: startOfDay, end: endOfDay);

      case TimeFrame.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(
          now.year,
          now.month + 1,
          0,
          23,
          59,
          59,
        );

        return DateTimeRange(start: start, end: end);

      case TimeFrame.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);

        return DateTimeRange(start: start, end: end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getDateRange();
    final categoryTotals = WGData.expensesByCategoryInDateRange(
      range.start,
      range.end,
    );

    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTimeFrameSelector(),
          if (total > 0 && categoryTotals.isNotEmpty) ...[
            _buildChart(context, categoryTotals),
          ] else
            _buildEmptyState(),
          _buildCategoryList(context, categoryTotals, total),
        ],
      ),
    );
  }

  Widget _buildTimeFrameSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: TimeFrame.values.map((frame) {
          final selected = _selectedTimeFrame == frame;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(frame.label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedTimeFrame = frame;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              'Keine Ausgaben in diesem Zeitraum',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    Map<String, double> categoryTotals,
  ) {
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxY = entries.first.value * 1.2;

    final barGroups = List.generate(entries.length, (index) {
      final entry = entries[index];

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: _categoryColor(entry.key),
            width: 28,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ausgaben nach Kategorie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceEvenly,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= entries.length) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            axisSide: AxisSide.bottom,
                            child: Text(
                              entries[index].key,
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    Map<String, double> categoryTotals,
    double total,
  ) {
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final percentage = total > 0
                  ? (entry.value / total * 100).round()
                  : 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _categoryColor(entry.key),
                  child: const Icon(Icons.category, size: 16),
                ),
                title: Text(entry.key),
                trailing: Text(
                  '€${entry.value.toStringAsFixed(2)} ($percentage%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            separatorBuilder: (context, index) =>
                const Divider(height: 1),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    final index = WGData.defaultExpenseCategories.indexOf(category);

    if (index != -1) {
      return WGData.memberColors[index % WGData.memberColors.length];
    }

    final customIndex = WGData.expenseCategories.indexOf(category);

    return WGData.memberColors[
        (customIndex + 3) % WGData.memberColors.length];
  }
}
