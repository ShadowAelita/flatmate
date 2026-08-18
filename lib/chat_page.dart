import 'dart:async';

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

  final Map<String, GlobalKey> _messageKeys = {};

  Map<String, dynamic>? _replyingTo;
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final member = WGData.currentMember;

    if (text.isEmpty || member == null) {
      return;
    }

    final replyToId = _replyingTo?['id']?.toString();

    final message = await WGData.addChatMessage(
      text: text,
      senderId: member.id,
      replyTo: replyToId,
    );

    if (!mounted || message == null) {
      return;
    }

    setState(() {
      _replyingTo = null;
    });

    _controller.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  WGMember? _getSender(String? senderId) {
    if (senderId == null) {
      return null;
    }

    for (final member in WGData.members) {
      if (member.id == senderId) {
        return member;
      }
    }

    return null;
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final dateTime = DateTime.tryParse(timestamp);

    if (dateTime == null) {
      return '';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  GlobalKey _getMessageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  Future<void> _scrollToMessage(String messageId) async {
    final key = _getMessageKey(messageId);
    final targetContext = key.currentContext;

    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );

    if (!mounted) {
      return;
    }

    _highlightTimer?.cancel();

    setState(() {
      _highlightedMessageId = messageId;
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final controller = TextEditingController(
      text: message['text']?.toString() ?? '',
    );

    final editedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nachricht bearbeiten'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Nachricht',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, text);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || editedText == null || editedText.isEmpty) {
      return;
    }

    final messageId = message['id']?.toString();

    if (messageId == null) {
      return;
    }

    try {
      await WGData.updateChatMessage(id: messageId, text: editedText);
    } catch (error) {
      debugPrint('Could not edit message: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nachricht konnte nicht bearbeitet werden.'),
        ),
      );
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nachricht löschen?'),
          content: const Text('Diese Nachricht wird dauerhaft gelöscht.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    final messageId = message['id']?.toString();

    if (messageId == null) {
      return;
    }

    // Update the UI immediately.
    setState(() {
      WGData.chatMessages.removeWhere(
        (existingMessage) => existingMessage['id']?.toString() == messageId,
      );

      // Any replies to the deleted message simply become
      // normal messages without a reply preview.
      for (final existingMessage in WGData.chatMessages) {
        if (existingMessage['replyTo']?.toString() == messageId) {
          existingMessage['replyTo'] = null;
        }
      }

      _messageKeys.remove(messageId);

      if (_replyingTo?['id']?.toString() == messageId) {
        _replyingTo = null;
      }

      if (_highlightedMessageId == messageId) {
        _highlightedMessageId = null;
      }
    });

    // Then update Supabase.
    try {
      await WGData.deleteChatMessage(messageId);
    } catch (error) {
      // If the database operation fails, reload the data so
      // the local UI is brought back into sync.
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nachricht konnte nicht gelöscht werden.'),
        ),
      );

      await WGData.initialize();

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _showMessageActions(
    Map<String, dynamic> message,
    WGMember sender,
    bool isCurrentMember,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentMember)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Bearbeiten'),
                  onTap: () {
                    Navigator.pop(sheetContext, 'edit');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Antworten'),
                onTap: () {
                  Navigator.pop(sheetContext, 'reply');
                },
              ),
              if (isCurrentMember)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Löschen'),
                  onTap: () {
                    Navigator.pop(sheetContext, 'delete');
                  },
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'delete') {
      await _deleteMessage(message);
    } else if (action == 'reply') {
      setState(() {
        _replyingTo = message;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageReplyPreview(Map<String, dynamic> message) {
    final replyToId = message['replyTo']?.toString();

    if (replyToId == null || replyToId.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? originalMessage;

    for (final existingMessage in WGData.chatMessages) {
      if (existingMessage['id']?.toString() == replyToId) {
        originalMessage = existingMessage;
        break;
      }
    }

    // The original message may have been deleted.
    // In that case, simply don't show a reply preview.
    if (originalMessage == null) {
      return const SizedBox.shrink();
    }

    final originalSender = _getSender(originalMessage['senderId']?.toString());

    if (originalSender == null) {
      return const SizedBox.shrink();
    }

    final originalMessageId = originalMessage['id']?.toString();

    if (originalMessageId == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        _scrollToMessage(originalMessageId);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
          border: Border(
            left: BorderSide(
              color: WGData.memberColor(originalSender),
              width: 3,
            ),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              originalSender.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: WGData.memberColor(originalSender),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              originalMessage['text']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final message = _replyingTo;

    if (message == null) {
      return const SizedBox.shrink();
    }

    final sender = _getSender(message['senderId']?.toString());

    if (sender == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: WGData.memberColor(sender), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antwort auf ${sender.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  message['text']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
            icon: const Icon(Icons.close),
            tooltip: 'Antwort abbrechen',
          ),
        ],
      ),
    );
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

                      final sender = _getSender(
                        message['senderId']?.toString(),
                      );

                      if (sender == null) {
                        return const SizedBox.shrink();
                      }

                      final isCurrentMember = currentMember?.id == sender.id;

                      final messageId = message['id']?.toString();

                      if (messageId == null) {
                        return const SizedBox.shrink();
                      }

                      final isHighlighted = _highlightedMessageId == messageId;

                      final bubbleColor = WGData.memberColor(sender)
                          .withValues(alpha: 0.20);

                      return Container(
                        key: _getMessageKey(messageId),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onLongPress: () {
                            _showMessageActions(
                              message,
                              sender,
                              isCurrentMember,
                            );
                          },
                          child: Align(
                            alignment: isCurrentMember
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? WGData.memberColor(sender)
                                          .withValues(alpha: 0.45)
                                    : bubbleColor,
                                borderRadius: BorderRadius.circular(16),
                                border: isHighlighted
                                    ? Border.all(
                                        color: WGData.memberColor(sender),
                                        width: 2,
                                      )
                                    : null,
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
                                        backgroundColor: WGData.memberColor(
                                          sender,
                                        ),
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

                                  if (message['replyTo'] != null) ...[
                                    _buildMessageReplyPreview(message),
                                    const SizedBox(height: 8),
                                  ],

                                  Text(
                                    message['text']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 16),
                                  ),

                                  const SizedBox(height: 4),

                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(
                                          message['timestamp']?.toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      if (message['edited'] == true) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '· bearbeitet',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) _buildReplyPreview(),

                  Padding(
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
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}
