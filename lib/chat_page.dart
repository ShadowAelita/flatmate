import 'dart:async';

import 'package:flutter/material.dart';

import 'shopping_page.dart';
import 'task_page.dart';
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
  String? _referenceId;
  String? _referenceType;
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  VoidCallback? _versionListener;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final member = WGData.currentMember;

     if ((text.isEmpty && _referenceId == null) || member == null) {
       return;
     }

    final replyToId = _replyingTo?['id']?.toString();

    final message = await WGData.addChatMessage(
      text: text,
      senderId: member.id,
      replyTo: replyToId,
      referenceId: _referenceId,
      referenceType: _referenceType,
    );

    if (!mounted || message == null) {
      return;
    }

    setState(() {
      _replyingTo = null;
      _referenceId = null;
      _referenceType = null;
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
    final editedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(
          text: message['text']?.toString() ?? '',
        );

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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
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

    _versionListener = () {
      if (!mounted) return;

      final lastMessage = WGData.latestChatMessage;
      if (lastMessage != null) {
        setState(() {});
      }
    };
    WGData.version.addListener(_versionListener!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WGData.markMessagesRead();

      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    if (_versionListener != null) {
      WGData.version.removeListener(_versionListener!);
    }
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

  Widget _buildReferenceBadge(String? referenceId, String? referenceType) {
    final description = WGData.resolveReferenceDescription(
      referenceId,
      referenceType,
    );

    if (description == null) {
      return const SizedBox.shrink();
    }

    IconData icon;

    switch (referenceType) {
      case 'task':
        icon = Icons.task_outlined;
        break;
      case 'shopping_item':
        icon = Icons.shopping_cart_outlined;
        break;
      default:
        icon = Icons.link;
    }

    return GestureDetector(
      onTap: () {
        if (referenceType == 'task') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskPage()),
          );
        } else if (referenceType == 'shopping_item') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingPage()),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(
              description,
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

  Widget _buildReferencePreview() {
    if (_referenceId == null || _referenceType == null) {
      return const SizedBox.shrink();
    }

    final description = WGData.resolveReferenceDescription(
      _referenceId,
      _referenceType,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Referenz: ${_referenceType == 'task' ? 'Aufgabe' : 'Einkauf'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description ?? 'Unbekannt',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _referenceId = null;
                _referenceType = null;
              });
            },
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Referenz entfernen',
          ),
        ],
      ),
    );
  }

  Future<void> _showReferenceSelector() async {
    String? selectedType;
    String? selectedId;
    String? selectedDescription;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ValueListenableBuilder<int>(
          valueListenable: WGData.version,
          builder: (context, _, child) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Referenz auswählen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        if (WGData.tasks.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Aufgaben',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...WGData.tasks.map((task) {
                            final taskId = task['id']?.toString() ?? '';
                            final taskTitle =
                                task['title']?.toString() ??
                                task['text']?.toString() ??
                                'Unbekannt';
                            final isSelected = selectedId == taskId;

                            return ListTile(
                              leading: Icon(
                                Icons.task_outlined,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              title: Text(taskTitle),
                              trailing: isSelected
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              selected: isSelected,
                              onTap: () {
                                setSheetState(() {
                                  selectedType = 'task';
                                  selectedId = taskId;
                                  selectedDescription = taskTitle;
                                });
                              },
                              onLongPress: () {
                                Navigator.pop(context);
                                _navigateToTask(taskId);
                              },
                            );
                          }),
                        ],
                        if (WGData.shoppingItems.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Einkauf',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...WGData.shoppingItems.map((item) {
                            final itemId = item['id']?.toString() ?? '';
                            final itemName =
                                item['name']?.toString() ??
                                item['text']?.toString() ??
                                'Unbekannt';
                            final isSelected = selectedId == itemId;

                            return ListTile(
                              leading: Icon(
                                Icons.shopping_cart_outlined,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              title: Text(itemName),
                              trailing: isSelected
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              selected: isSelected,
                              onTap: () {
                                setSheetState(() {
                                  selectedType = 'shopping_item';
                                  selectedId = itemId;
                                  selectedDescription = itemName;
                                });
                              },
                              onLongPress: () {
                                Navigator.pop(context);
                                _navigateToShopping();
                              },
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Abbrechen'),
                                ),
                              ),
                              Expanded(
                                child: FilledButton(
                                  onPressed: selectedId != null
                                      ? () {
                                          Navigator.pop(context, {
                                            'type': selectedType!,
                                            'id': selectedId!,
                                            'desc': selectedDescription!,
                                          });
                                        }
                                      : null,
                                  child: const Text('Fügen'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });
            },
          );
        },
      );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _referenceId = result['id'];
      _referenceType = result['type'];
    });
  }

  void _navigateToTask(String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskPage(),
      ),
    );
  }

  void _navigateToShopping() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ShoppingPage(),
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

                                  if (message['referenceId'] != null &&
                                      message['referenceType'] != null)
                                    _buildReferenceBadge(
                                      message['referenceId']?.toString(),
                                      message['referenceType']?.toString(),
                                    ),

                                  if (message['text']?.toString().isNotEmpty ??
                                      false)
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
                  if (_referenceId != null && _referenceType != null)
                    _buildReferencePreview(),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton.filled(
                          onPressed: _showReferenceSelector,
                          icon: const Icon(Icons.add),
                          tooltip: 'Referenz hinzufügen',
                        ),
                        const SizedBox(width: 8),
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
