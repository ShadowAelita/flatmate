import 'package:flutter/material.dart';

import 'wg_data.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final member = WGData.currentMember;

    if (text.isEmpty || member == null) {
      return;
    }

    setState(() {
      WGData.chatMessages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'senderId': member.id,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _controller.clear();

    await WGData.save();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  WGMember? _getSender(String senderId) {
    for (final member in WGData.members) {
      if (member.id == senderId) {
        return member;
      }
    }

    return null;
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);

    if (dateTime == null) {
      return '';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = WGData.currentMember;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: WGData.chatMessages.isEmpty
                ? Center(
                    child: Text(
                      'Noch keine Nachrichten',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: WGData.chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = WGData.chatMessages[index];
                      final sender = _getSender(message['senderId']);

                      if (sender == null) {
                        return const SizedBox.shrink();
                      }

                      final isCurrentMember = currentMember?.id == sender.id;
                      final bubbleColor = WGData.memberColor(sender)
                          .withValues(alpha: 0.20);
                      return Align(
                        alignment: isCurrentMember
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: isCurrentMember
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: WGData.memberColor(sender),
                                    child: Text(
                                      sender.name.isNotEmpty
                                          ? sender.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sender.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                message['text'],
                                style: const TextStyle(fontSize: 16),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                _formatTime(message['timestamp']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          if (currentMember == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Wähle zuerst einen Bewohner unter "Unsere WG".',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Nachricht schreiben...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
