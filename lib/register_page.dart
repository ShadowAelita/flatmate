import 'package:flutter/material.dart';

import 'home_page.dart';
import 'wg_data.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _flatshareNameController =
      TextEditingController(text: 'Unsere WG');
  final TextEditingController _inviteCodeController = TextEditingController();

  int _selectedColorIndex = 0;
  bool _isCreateMode = true;
  bool _showFlatshareStep = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _flatshareNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createFlatshare() async {
    final name = _nameController.text.trim();
    final flatshareName = _flatshareNameController.text.trim();

    if (name.isEmpty || flatshareName.isEmpty) return;

    setState(() => _isLoading = true);

    final result = await WGData.createHousehold(
      householdName: flatshareName,
      memberName: name,
      colorIndex: _selectedColorIndex,
    );

    if (result.success && mounted) {
      _navigateToHome();
    } else if (mounted) {
      String message;

      if (result.error == 'schema') {
        message = 'Datenbank nicht bereit. '
            'Bitte führe die Migration aus und versuche es erneut.';
      } else {
        message = 'Konnte die WG nicht erstellen. '
            'Bitte prüfe deine Internetverbindung.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinFlatshare() async {
    final name = _nameController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    if (name.isEmpty || inviteCode.isEmpty) return;

    setState(() => _isLoading = true);

    final result = await WGData.joinHouseholdByInviteCode(
      inviteCode: inviteCode,
      memberName: name,
      colorIndex: _selectedColorIndex,
    );

    if (result.success && mounted) {
      _navigateToHome();
    } else if (mounted) {
      String message;

      if (result.error == 'code') {
        message = 'Einladungscode nicht gefunden. '
            'Bitte überprüfe den Code und versuche es erneut.';
      } else if (result.error == 'schema') {
        message = 'Datenbank nicht bereit. '
            'Bitte führe die Migration aus und versuche es erneut.';
      } else if (result.error == 'permission') {
        message = 'Zugriff verweigert (RLS-Richtlinie). '
            'Bitte führe die RLS-Policy-Migration aus.';
      } else if (result.error == 'network') {
        message = 'Verbindungsfehler. Bitte prüfe deine Internetverbindung.';
      } else {
        message = 'Konnte der WG nicht beitreten. Bitte versuche es später.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GatePage()),
      (route) => false,
    );
  }

  Future<void> _testConnection() async {
    final error = await WGData.testConnection();

    if (!mounted) return;

    String message;
    String title;

    if (error == null) {
      title = 'Verbindung OK';
      message = 'Supabase ist erreichbar.';
    } else if (error == 'schema') {
      title = 'Schema-Fehler';
      message = 'Die Datenbank-Tabellen oder -Spalten '
          'sind nicht vorhanden. Bitte führe die Migration aus.';
    } else if (error == 'permission') {
      title = 'RLS-Fehler';
      message = 'Zugriff verweigert. Bitte prüfe die RLS-Richtlinien '
          'in Supabase.';
    } else {
      title = 'Verbindungsfehler';
      message = 'Kann nicht mit Supabase verbunden werden. '
          'Prüfe deine Internetverbindung.';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _goToFlatshareStep() {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _showFlatshareStep = true);
  }

  void _backToProfileStep() {
    setState(() => _showFlatshareStep = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flatmate')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _showFlatshareStep
                    ? _buildFlatshareStep()
                    : _buildProfileStep(),
              ),
            ),
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wer bist du?',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Gib deinen Namen ein und wähle eine Farbe.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z. B. Knut',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _goToFlatshareStep(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Text(
          'Farbe',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(WGData.memberColors.length, (index) {
            final color = WGData.memberColors[index];
            final selected = _selectedColorIndex == index;

            return GestureDetector(
              onTap: () => setState(() => _selectedColorIndex = index),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: selected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Text(
          'Diese Farbe wird in der WG angezeigt.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nameController.text.trim().isNotEmpty
              ? _goToFlatshareStep
              : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Weiter'),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _testConnection,
          icon: const Icon(Icons.wifi),
          label: const Text('Verbindung testen'),
        ),
      ],
    );
  }

  Widget _buildFlatshareStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WG erstellen oder beitreten',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Erstelle eine neue WG oder tritt einer '
              'bestehenden mit einem Einladungscode bei.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ToggleButtons(
          isSelected: [_isCreateMode, !_isCreateMode],
          onPressed: (index) {
            setState(() => _isCreateMode = index == 0);
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Erstellen'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Beitreten'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isCreateMode) ...[
          TextField(
            controller: _flatshareNameController,
            decoration: const InputDecoration(
              labelText: 'Name der WG',
              hintText: 'z. B. Wohnung 3',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _createFlatshare(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _createFlatshare,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('WG erstellen'),
          ),
        ] else ...[
          TextField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(
              labelText: 'Einladungscode',
              hintText: 'z. B. A1B2C3',
              prefixIcon: Icon(Icons.qr_code_outlined),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _joinFlatshare(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _inviteCodeController.text.trim().isNotEmpty
                ? _joinFlatshare
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Beitreten'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _backToProfileStep,
          child: const Text('Zurück'),
        ),
      ],
    );
  }
}

class GatePage extends StatelessWidget {
  const GatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WGData.version,
      builder: (context, _, child) {
        if (WGData.householdId == null) {
          return const RegisterPage();
        }

        if (WGData.currentMemberId == null &&
            WGData.members.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (WGData.currentMemberId == null &&
                WGData.members.isNotEmpty) {
              WGData.setCurrentMember(WGData.members.first.id);
            }
          });
        }

        return const HomePage();
      },
    );
  }
}
