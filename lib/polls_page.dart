import 'package:flutter/material.dart';

import 'wg_data.dart';

class PollsPage extends StatefulWidget {
  const PollsPage({super.key});

  @override
  State<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends State<PollsPage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionController = TextEditingController();
  final List<String> _newOptions = [];

  @override
  void initState() {
    super.initState();

    WGData.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    WGData.version.removeListener(_onVersionChanged);
    _questionController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  void _onVersionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addPoll() async {
    final question = _questionController.text.trim();

    if (question.isEmpty || _newOptions.isEmpty) return;

    await WGData.addPoll(question, List<String>.from(_newOptions));

    _questionController.clear();
    _newOptions.clear();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addOption() async {
    final option = _optionController.text.trim();

    if (option.isEmpty) return;

    setState(() {
      _newOptions.add(option);
      _optionController.clear();
    });
  }

  Future<void> _vote(String pollId, String optionId) async {
    await WGData.votePoll(pollId, optionId);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _closePoll(String pollId) async {
    await WGData.closePoll(pollId);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deletePoll(String pollId) async {
    await WGData.deletePoll(pollId);

    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _optionsForPoll(String pollId) {
    return WGData.pollOptions
        .where((o) => o['poll_id']?.toString() == pollId)
        .toList();
  }

  int _voteCount(String optionId) {
    return WGData.pollVotes
        .where((v) => v['option_id']?.toString() == optionId)
        .length;
  }

  bool _hasVoted(String pollId) {
    final currentMemberId = WGData.currentMemberId;

    if (currentMemberId == null) return false;

    return WGData.pollVotes.any(
      (v) => v['poll_id']?.toString() == pollId && v['member_id']?.toString() == currentMemberId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Umfragen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: 'Frage',
                    hintText: 'z. B. Pizza oder Sushi?',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionController,
                        decoration: const InputDecoration(
                          labelText: 'Option',
                          hintText: 'z. B. Pizza',
                        ),
                        onSubmitted: (_) => _addOption(),
                      ),
                    ),
                    IconButton(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_newOptions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: _newOptions
                        .map((o) => Chip(
                              label: Text(o),
                              onDeleted: () {
                                setState(() {
                                  _newOptions.remove(o);
                                });
                              },
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _addPoll,
                  child: const Text('Umfrage erstellen'),
                ),
              ],
            ),
          ),
          Expanded(
            child: WGData.polls.isEmpty
                ? Center(
                    child: Text(
                      'Keine Umfragen',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: WGData.polls.length,
                    itemBuilder: (context, index) {
                      final poll = WGData.polls[index];
                      final options = _optionsForPoll(poll['id'].toString());
                      final closed = poll['closed'] == true;
                      final voted = _hasVoted(poll['id'].toString());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      poll['question']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!closed)
                                    TextButton(
                                      onPressed: () => _closePoll(poll['id'].toString()),
                                      child: const Text('Schließen'),
                                    ),
                                  IconButton(
                                    onPressed: () => _deletePoll(poll['id'].toString()),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...options.map((option) {
                                final count = _voteCount(option['id'].toString());
                                final totalVotes = WGData.pollVotes
                                    .where((v) => v['poll_id']?.toString() == poll['id'].toString())
                                    .length;
                                final percentage = totalVotes > 0
                                    ? (count / totalVotes * 100).toStringAsFixed(0)
                                    : '0';

                                return ListTile(
                                  title: Text(option['text']?.toString() ?? ''),
                                  trailing: Text('$count ($percentage%)'),
                                  onTap: (!closed && !voted)
                                      ? () => _vote(poll['id'].toString(), option['id'].toString())
                                      : null,
                                );
                              }),
                              if (closed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Umfrage geschlossen',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
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
