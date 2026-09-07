import 'package:flutter/material.dart';

import 'wg_data.dart';

class RentSplitPage extends StatefulWidget {
  const RentSplitPage({super.key});

  @override
  State<RentSplitPage> createState() => _RentSplitPageState();
}

class _RentSplitPageState extends State<RentSplitPage> {
  final TextEditingController _rentController = TextEditingController();
  final Map<String, TextEditingController> _sizeControllers = {};
  final Map<String, double> _shares = {};

  @override
  void initState() {
    super.initState();

    for (final member in WGData.members) {
      _sizeControllers[member.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _sizeControllers.values) {
      controller.dispose();
    }

    _rentController.dispose();
    super.dispose();
  }

  void _calculate() {
    final totalRent = double.tryParse(_rentController.text) ?? 0;

    if (totalRent <= 0) {
      setState(() => _shares.clear());
      return;
    }

    final sizes = <String, double>{};

    for (final member in WGData.members) {
      final sizeText = _sizeControllers[member.id]?.text.trim() ?? '0';
      final size = double.tryParse(sizeText) ?? 0;
      sizes[member.id] = size > 0 ? size : 1;
    }

    final totalSize = sizes.values.fold(0.0, (a, b) => a + b);

    if (totalSize <= 0) {
      setState(() => _shares.clear());
      return;
    }

    final shares = <String, double>{};

    for (final member in WGData.members) {
      final size = sizes[member.id] ?? 1;
      shares[member.id] = totalRent * (size / totalSize);
    }

    setState(() {
      _shares.clear();
      _shares.addAll(shares);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mietanteile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Gesamtmiete (€)',
                hintText: 'z. B. 1200',
              ),
            ),
            const SizedBox(height: 16),
            ...WGData.members.map((member) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: WGData.memberColor(member),
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _sizeControllers[member.id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Anteil',
                          hintText: 'z. B. 15',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: Text(
                        _shares[member.id] != null
                            ? '€${_shares[member.id]!.toStringAsFixed(2)}'
                            : '€0.00',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _calculate,
              child: const Text('Berechnen'),
            ),
          ],
        ),
      ),
    );
  }
}
