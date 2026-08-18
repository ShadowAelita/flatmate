import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WGMember {
  final String id;
  final String name;
  final int colorIndex;

  const WGMember({
    required this.id,
    required this.name,
    required this.colorIndex,
  });
}

class WGData {
  static final List<WGMember> members = [];
  static final List<Map<String, dynamic>> shoppingItems = [];
  static final List<Map<String, dynamic>> tasks = [];
  static final List<Map<String, dynamic>> chatMessages = [];

  static String? householdId;
  static String? currentMemberId;

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static final SupabaseClient _supabase = Supabase.instance.client;

  static SharedPreferences? _prefs;

  static RealtimeChannel? _realtimeChannel;

  static Future<void>? _initializationFuture;
  static Future<void>? _syncFuture;

  static bool _isOnline = false;
  static const String _pendingOperationsKey = 'wg_pending_operations';
  static const String _cachePrefix = 'wg_cache_';

  static const List<Color> memberColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.purple,
  ];

  static bool get isOnline => _isOnline;
  static bool get hasPendingOperations => _readPendingOperations().isNotEmpty;

  static Color memberColor(WGMember member) {
    return memberColors[member.colorIndex % memberColors.length];
  }

  static WGMember? get currentMember {
    if (currentMemberId == null) {
      return null;
    }

    for (final member in members) {
      if (member.id == currentMemberId) {
        return member;
      }
    }

    return null;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> initialize() {
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    final future = _initializeInternal();

    _initializationFuture = future;

    future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });

    return future;
  }

  static Future<void> _initializeInternal() async {
    _prefs ??= await SharedPreferences.getInstance();

    final prefs = _prefs!;

    householdId = prefs.getString('householdId');
    currentMemberId = prefs.getString('currentMemberId');

    // ------------------------------------------------------------
    // IMPORTANT:
    // Load local data FIRST.
    //
    // The UI therefore has something to display even when:
    // - the phone is offline
    // - Supabase is slow
    // - Realtime is unavailable
    // ------------------------------------------------------------

    _loadCache();

    version.value++;

    // Existing household:
    // immediately show cached state and synchronize in background.
    if (householdId != null) {
      await _subscribeToRealtime();

      unawaited(_syncOnline());
      return;
    }

    // First installation with no household yet.
    //
    // We cannot create a household offline, so this is the only
    // situation where startup may need to contact Supabase.
    try {
      final response = await _supabase
          .from('households')
          .insert({'name': 'Unsere WG'})
          .select()
          .single()
          .timeout(const Duration(seconds: 6));

      householdId = response['id'] as String;

      await prefs.setString('householdId', householdId!);

      await _subscribeToRealtime();

      unawaited(_syncOnline());
    } catch (error) {
      debugPrint('Could not create household: $error');

      // The application still starts.
      // There simply isn't any household data yet.
      _isOnline = false;
      version.value++;
    }
  }

  // ============================================================
  // LOCAL CACHE
  // ============================================================

  static String get _cacheKey {
    final id = householdId;

    if (id == null) {
      return '';
    }

    return '$_cachePrefix$id';
  }

  static void _loadCache() {
    final key = _cacheKey;

    if (key.isEmpty || _prefs == null) {
      return;
    }

    try {
      final raw = _prefs!.getString(key);

      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return;
      }

      final cached = Map<String, dynamic>.from(decoded);

      // MEMBERS
      members.clear();

      final cachedMembers = cached['members'];

      if (cachedMembers is List) {
        for (final row in cachedMembers) {
          if (row is! Map) {
            continue;
          }

          members.add(
            WGMember(
              id: row['id'].toString(),
              name: row['name']?.toString() ?? '',
              colorIndex: row['colorIndex'] as int? ?? 0,
            ),
          );
        }
      }

      // TASKS
      tasks.clear();

      final cachedTasks = cached['tasks'];

      if (cachedTasks is List) {
        for (final row in cachedTasks) {
          if (row is Map) {
            tasks.add(Map<String, dynamic>.from(row));
          }
        }
      }

      // SHOPPING
      shoppingItems.clear();

      final cachedShopping = cached['shoppingItems'];

      if (cachedShopping is List) {
        for (final row in cachedShopping) {
          if (row is Map) {
            shoppingItems.add(Map<String, dynamic>.from(row));
          }
        }
      }

      // CHAT
      chatMessages.clear();

      final cachedChat = cached['chatMessages'];

      if (cachedChat is List) {
        for (final row in cachedChat) {
          if (row is Map) {
            chatMessages.add(Map<String, dynamic>.from(row));
          }
        }
      }

      _sortTasksLocally();
    } catch (error) {
      debugPrint('Could not load local cache: $error');
    }
  }

  static Future<void> _saveCache() async {
    if (_prefs == null || householdId == null) {
      return;
    }

    try {
      final data = <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'members': members
            .map(
              (member) => {
                'id': member.id,
                'name': member.name,
                'colorIndex': member.colorIndex,
              },
            )
            .toList(),
        'tasks': tasks.map(Map<String, dynamic>.from).toList(),
        'shoppingItems': shoppingItems.map(Map<String, dynamic>.from).toList(),
        'chatMessages': chatMessages.map(Map<String, dynamic>.from).toList(),
      };

      await _prefs!.setString(_cacheKey, jsonEncode(data));
    } catch (error) {
      debugPrint('Could not save local cache: $error');
    }
  }

  static void _notifyAndCache() {
    version.value++;

    // Never make UI updates wait for disk I/O.
    unawaited(_saveCache());
  }

  // ============================================================
  // UUID
  // ============================================================

  static String _newId() {
    final random = Random.secure();

    String hex(int count) {
      return List.generate(
        count,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
    }

    return '${hex(8)}-'
        '${hex(4)}-'
        '4${hex(3)}-'
        '${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-'
        '${hex(12)}';
  }

  // ============================================================
  // PENDING OFFLINE OPERATIONS
  // ============================================================

  static List<Map<String, dynamic>> _readPendingOperations() {
    if (_prefs == null) {
      return [];
    }

    try {
      final raw = _prefs!.getString(_pendingOperationsKey);

      if (raw == null || raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (error) {
      debugPrint('Could not read pending operations: $error');
      return [];
    }
  }

  static Future<void> _writePendingOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    if (_prefs == null) {
      return;
    }

    await _prefs!.setString(_pendingOperationsKey, jsonEncode(operations));
  }

  static Future<void> _queueOperation(
    String type,
    Map<String, dynamic> data,
  ) async {
    final operations = _readPendingOperations();

    operations.add({
      'type': type,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _writePendingOperations(operations);
  }

  static Future<void> _flushPendingOperations() async {
    if (householdId == null) {
      return;
    }

    final operations = _readPendingOperations();

    if (operations.isEmpty) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];

    for (var index = 0; index < operations.length; index++) {
      final operation = operations[index];

      try {
        await _executeOperation(operation);
      } catch (error) {
        debugPrint('Offline operation failed; keeping it queued: $error');

        remaining.addAll(operations.sublist(index));
        break;
      }
    }

    await _writePendingOperations(remaining);
  }

  static Future<void> _executeOperation(Map<String, dynamic> operation) async {
    final type = operation['type']?.toString();
    final data = Map<String, dynamic>.from(operation['data'] as Map);

    switch (type) {
      // ----------------------------------------------------------
      // MEMBERS
      // ----------------------------------------------------------

      case 'member_insert':
        await _supabase.from('members').insert(data);
        break;

      case 'member_update':
        await _supabase
            .from('members')
            .update(Map<String, dynamic>.from(data['updates'] as Map))
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'member_delete':
        await _supabase
            .from('members')
            .delete()
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      // ----------------------------------------------------------
      // TASKS
      // ----------------------------------------------------------

      case 'task_insert':
        await _supabase.from('tasks').insert(data);
        break;

      case 'task_update':
        await _supabase
            .from('tasks')
            .update(Map<String, dynamic>.from(data['updates'] as Map))
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'task_delete':
        await _supabase
            .from('tasks')
            .delete()
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'task_order':
        final orders = data['orders'];

        if (orders is List) {
          for (final entry in orders) {
            final row = Map<String, dynamic>.from(entry as Map);

            await _supabase
                .from('tasks')
                .update({'sort_order': row['sortOrder']})
                .eq('id', row['id'])
                .eq('household_id', householdId!);
          }
        }
        break;

      // ----------------------------------------------------------
      // SHOPPING
      // ----------------------------------------------------------

      case 'shopping_insert':
        await _supabase.from('shopping_items').insert(data);
        break;

      case 'shopping_update':
        await _supabase
            .from('shopping_items')
            .update(Map<String, dynamic>.from(data['updates'] as Map))
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'shopping_delete':
        await _supabase
            .from('shopping_items')
            .delete()
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      // ----------------------------------------------------------
      // CHAT
      // ----------------------------------------------------------

      case 'chat_insert':
        await _supabase.from('chat_messages').insert(data);
        break;

      case 'chat_update':
        await _supabase
            .from('chat_messages')
            .update(Map<String, dynamic>.from(data['updates'] as Map))
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'chat_delete':
        await _supabase
            .from('chat_messages')
            .update({'reply_to': null})
            .eq('reply_to', data['id'])
            .eq('household_id', householdId!);

        await _supabase
            .from('chat_messages')
            .delete()
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      default:
        throw Exception('Unknown offline operation: $type');
    }
  }

  // ============================================================
  // ONLINE SYNC
  // ============================================================

  static Future<void> _syncOnline() {
    if (_syncFuture != null) {
      return _syncFuture!;
    }

    final future = _syncOnlineInternal();

    _syncFuture = future;

    future.whenComplete(() {
      if (identical(_syncFuture, future)) {
        _syncFuture = null;
      }
    });

    return future;
  }

  static Future<void> _syncOnlineInternal() async {
    if (householdId == null) {
      return;
    }

    try {
      // Pending local changes MUST reach the server before we
      // replace the local cache with server data.
      await _flushPendingOperations();

      await Future.wait([
        _loadMembers(),
        _loadTasks(),
        _loadShoppingItems(),
        _loadChatMessages(),
      ]).timeout(const Duration(seconds: 8));

      _isOnline = true;

      await _saveCache();

      version.value++;
    } catch (error) {
      _isOnline = false;

      debugPrint('Online synchronization failed: $error');

      // Keep the cached state.
      version.value++;
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  static Future<void> _unsubscribeFromRealtime() async {
    final channel = _realtimeChannel;

    if (channel != null) {
      try {
        await _supabase.removeChannel(channel);
      } catch (error) {
        debugPrint('Could not remove Realtime channel: $error');
      }
    }

    _realtimeChannel = null;
  }

  static Future<void> _subscribeToRealtime() async {
    if (householdId == null) {
      return;
    }

    await _unsubscribeFromRealtime();

    final currentHouseholdId = householdId!;

    final channel = _supabase.channel('wg-household-$currentHouseholdId');

    // ------------------------------------------------------------
    // MEMBERS
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'members',
      callback: (payload) {
        _deferRealtime(() {
          _handleMembersRealtime(payload, currentHouseholdId);
        });
      },
    );

    // ------------------------------------------------------------
    // TASKS
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (payload) {
        _deferRealtime(() {
          _handleTasksRealtime(payload, currentHouseholdId);
        });
      },
    );

    // ------------------------------------------------------------
    // SHOPPING
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'shopping_items',
      callback: (payload) {
        _deferRealtime(() {
          _handleShoppingRealtime(payload, currentHouseholdId);
        });
      },
    );

    // ------------------------------------------------------------
    // CHAT
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      callback: (payload) {
        _deferRealtime(() {
          _handleChatRealtime(payload, currentHouseholdId);
        });
      },
    );

    _realtimeChannel = channel;

    channel.subscribe((status, error) {
      debugPrint('Realtime status: $status${error == null ? '' : ' / $error'}');

      if (status == RealtimeSubscribeStatus.subscribed) {
        _isOnline = true;

        unawaited(_syncOnline());
      }
    });
  }

  static void _deferRealtime(VoidCallback callback) {
    // Do not mutate lists synchronously from inside a Realtime
    // callback while Flutter may be building widgets.
    scheduleMicrotask(callback);
  }

  // ============================================================
  // REALTIME HANDLERS
  // ============================================================

  static bool _belongsToHousehold(
    PostgresChangePayload payload,
    String currentHouseholdId,
  ) {
    final newHousehold = payload.newRecord['household_id']?.toString();
    final oldHousehold = payload.oldRecord['household_id']?.toString();

    return newHousehold == currentHouseholdId ||
        oldHousehold == currentHouseholdId;
  }

  static void _handleMembersRealtime(
    PostgresChangePayload payload,
    String currentHouseholdId,
  ) {
    if (!_belongsToHousehold(payload, currentHouseholdId)) {
      return;
    }

    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final id = (newRecord['id'] ?? oldRecord['id'])?.toString();

    if (id == null) {
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (members.any((member) => member.id == id)) {
          return;
        }

        members.add(
          WGMember(
            id: id,
            name: newRecord['name']?.toString() ?? '',
            colorIndex: newRecord['color_index'] as int? ?? 0,
          ),
        );
        break;

      case PostgresChangeEvent.update:
        final index = members.indexWhere((member) => member.id == id);

        final updated = WGMember(
          id: id,
          name: newRecord['name']?.toString() ?? '',
          colorIndex: newRecord['color_index'] as int? ?? 0,
        );

        if (index == -1) {
          members.add(updated);
        } else {
          members[index] = updated;
        }
        break;

      case PostgresChangeEvent.delete:
        members.removeWhere((member) => member.id == id);

        if (currentMemberId == id) {
          currentMemberId = null;

          unawaited(_prefs?.remove('currentMemberId'));
        }
        break;

      default:
        return;
    }

    _notifyAndCache();
  }

  static void _handleTasksRealtime(
    PostgresChangePayload payload,
    String currentHouseholdId,
  ) {
    if (!_belongsToHousehold(payload, currentHouseholdId)) {
      return;
    }

    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final id = (newRecord['id'] ?? oldRecord['id'])?.toString();

    if (id == null) {
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (tasks.any((task) => task['id']?.toString() == id)) {
          return;
        }

        tasks.add(_taskFromRow(newRecord));
        break;

      case PostgresChangeEvent.update:
        final index = tasks.indexWhere((task) => task['id']?.toString() == id);

        final existingSortOrder = index == -1
            ? null
            : tasks[index]['sortOrder'];

        final updated = _taskFromRow(
          newRecord,
          fallbackSortOrder: existingSortOrder,
        );

        if (index == -1) {
          tasks.add(updated);
        } else {
          tasks[index] = updated;
        }
        break;

      case PostgresChangeEvent.delete:
        tasks.removeWhere((task) => task['id']?.toString() == id);
        break;

      default:
        return;
    }

    _sortTasksLocally();
    _notifyAndCache();
  }

  static void _handleShoppingRealtime(
    PostgresChangePayload payload,
    String currentHouseholdId,
  ) {
    if (!_belongsToHousehold(payload, currentHouseholdId)) {
      return;
    }

    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final id = (newRecord['id'] ?? oldRecord['id'])?.toString();

    if (id == null) {
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (shoppingItems.any((item) => item['id']?.toString() == id)) {
          return;
        }

        shoppingItems.add(_shoppingFromRow(newRecord));
        break;

      case PostgresChangeEvent.update:
        final index = shoppingItems.indexWhere(
          (item) => item['id']?.toString() == id,
        );

        final updated = _shoppingFromRow(newRecord);

        if (index == -1) {
          shoppingItems.add(updated);
        } else {
          shoppingItems[index] = updated;
        }
        break;

      case PostgresChangeEvent.delete:
        shoppingItems.removeWhere((item) => item['id']?.toString() == id);
        break;

      default:
        return;
    }

    _notifyAndCache();
  }

  static void _handleChatRealtime(
    PostgresChangePayload payload,
    String currentHouseholdId,
  ) {
    if (!_belongsToHousehold(payload, currentHouseholdId)) {
      return;
    }

    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final id = (newRecord['id'] ?? oldRecord['id'])?.toString();

    if (id == null) {
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (chatMessages.any((message) => message['id']?.toString() == id)) {
          return;
        }

        chatMessages.add(_chatFromRow(newRecord));
        break;

      case PostgresChangeEvent.update:
        final index = chatMessages.indexWhere(
          (message) => message['id']?.toString() == id,
        );

        final updated = _chatFromRow(newRecord);

        if (index == -1) {
          chatMessages.add(updated);
        } else {
          chatMessages[index] = updated;
        }
        break;

      case PostgresChangeEvent.delete:
        chatMessages.removeWhere((message) => message['id']?.toString() == id);

        for (final message in chatMessages) {
          if (message['replyTo']?.toString() == id) {
            message['replyTo'] = null;
          }
        }
        break;

      default:
        return;
    }

    chatMessages.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '');

      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '');

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;

      return aTime.compareTo(bTime);
    });

    _notifyAndCache();
  }

  // ============================================================
  // ROW CONVERTERS
  // ============================================================

  static Map<String, dynamic> _taskFromRow(
    Map<String, dynamic> row, {
    dynamic fallbackSortOrder,
  }) {
    return {
      'id': row['id'],
      'name': row['name'],
      'completed': row['completed'] ?? false,
      'assignedTo': row['assigned_to'],
      'dueDate': row['due_date'],
      'repeat': row['repeat'] ?? 'none',
      'sortOrder': row['sort_order'] ?? fallbackSortOrder ?? 0,
    };
  }

  static Map<String, dynamic> _shoppingFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'completed': row['completed'] ?? false,
      'quantity': row['quantity'] ?? 1,
      'claimedBy': row['claimed_by'],
    };
  }

  static Map<String, dynamic> _chatFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'text': row['text'],
      'senderId': row['sender_id'],
      'timestamp': row['timestamp'],
      'edited': row['edited'] ?? false,
      'replyTo': row['reply_to'],
    };
  }

  // ============================================================
  // SERVER LOAD
  // ============================================================

  static Future<void> _loadMembers() async {
    if (householdId == null) return;

    final response = await _supabase
        .from('members')
        .select('id, name, color_index')
        .eq('household_id', householdId!)
        .order('created_at');

    members.clear();

    for (final row in response) {
      members.add(
        WGMember(
          id: row['id'] as String,
          name: row['name'] as String,
          colorIndex: row['color_index'] as int? ?? 0,
        ),
      );
    }

    if (currentMemberId != null &&
        !members.any((member) => member.id == currentMemberId)) {
      currentMemberId = null;
      await _prefs?.remove('currentMemberId');
    }
  }

  static Future<void> _loadTasks() async {
    if (householdId == null) return;

    final response = await _supabase
        .from('tasks')
        .select(
          'id, name, completed, assigned_to, due_date, repeat, sort_order',
        )
        .eq('household_id', householdId!)
        .order('sort_order')
        .order('created_at');

    tasks.clear();

    for (final row in response) {
      tasks.add(_taskFromRow(row));
    }

    _sortTasksLocally();
  }

  static Future<void> _loadShoppingItems() async {
    if (householdId == null) return;

    final response = await _supabase
        .from('shopping_items')
        .select('id, name, completed, quantity, claimed_by, created_at')
        .eq('household_id', householdId!)
        .order('created_at');

    shoppingItems.clear();

    for (final row in response) {
      shoppingItems.add(_shoppingFromRow(row));
    }
  }

  static Future<void> _loadChatMessages() async {
    if (householdId == null) return;

    final response = await _supabase
        .from('chat_messages')
        .select('id, text, sender_id, timestamp, edited, reply_to')
        .eq('household_id', householdId!)
        .order('timestamp');

    chatMessages.clear();

    for (final row in response) {
      chatMessages.add(_chatFromRow(row));
    }
  }

  // ============================================================
  // TASK ORDER
  // ============================================================

  static void _sortTasksLocally() {
    tasks.sort((a, b) {
      final aOrder = a['sortOrder'];
      final bOrder = b['sortOrder'];

      final aInt = aOrder is num ? aOrder.toInt() : 0;
      final bInt = bOrder is num ? bOrder.toInt() : 0;

      return aInt.compareTo(bInt);
    });
  }

  static Future<void> _saveTaskOrder() async {
    if (householdId == null) {
      return;
    }

    final orders = <Map<String, dynamic>>[];

    for (var index = 0; index < tasks.length; index++) {
      final taskId = tasks[index]['id'];

      tasks[index]['sortOrder'] = index;

      orders.add({'id': taskId, 'sortOrder': index});
    }

    try {
      for (final order in orders) {
        await _supabase
            .from('tasks')
            .update({'sort_order': order['sortOrder']})
            .eq('id', order['id'])
            .eq('household_id', householdId!);
      }

      _isOnline = true;
      await _saveCache();
    } catch (error) {
      _isOnline = false;

      await _queueOperation('task_order', {'orders': orders});

      await _saveCache();
    }
  }

  static Future<void> updateTaskOrder() async {
    _sortTasksLocally();

    for (var index = 0; index < tasks.length; index++) {
      tasks[index]['sortOrder'] = index;
    }

    _notifyAndCache();

    await _saveTaskOrder();
  }

  // ============================================================
  // MEMBERS
  // ============================================================

  static Future<WGMember?> addMember({
    required String name,
    required int colorIndex,
  }) async {
    if (householdId == null) {
      return null;
    }

    final id = _newId();

    final member = WGMember(id: id, name: name, colorIndex: colorIndex);

    members.add(member);
    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'color_index': colorIndex,
    };

    try {
      await _supabase.from('members').insert(data);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('member_insert', data);
    }

    return member;
  }

  static Future<void> updateMember({
    required String id,
    required String name,
    required int colorIndex,
  }) async {
    if (householdId == null) return;

    final index = members.indexWhere((member) => member.id == id);

    if (index != -1) {
      members[index] = WGMember(id: id, name: name, colorIndex: colorIndex);

      _notifyAndCache();
    }

    final updates = {'name': name, 'color_index': colorIndex};

    try {
      await _supabase
          .from('members')
          .update(updates)
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('member_update', {'id': id, 'updates': updates});
    }
  }

  static Future<void> deleteMember(String id) async {
    if (householdId == null) return;

    members.removeWhere((member) => member.id == id);

    if (currentMemberId == id) {
      currentMemberId = null;
      await _prefs?.remove('currentMemberId');
    }

    for (final task in tasks) {
      if (task['assignedTo'] == id) {
        task['assignedTo'] = null;
      }
    }

    for (final item in shoppingItems) {
      if (item['claimedBy'] == id) {
        item['claimedBy'] = null;
      }
    }

    _notifyAndCache();

    try {
      await _supabase
          .from('members')
          .delete()
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('member_delete', {'id': id});
    }
  }

  // ============================================================
  // TASKS
  // ============================================================

  static Future<Map<String, dynamic>?> addTask({
    required String name,
    String? assignedTo,
    String? dueDate,
    String repeat = 'none',
  }) async {
    if (householdId == null) {
      return null;
    }

    final id = _newId();
    final sortOrder = tasks.length;

    final task = {
      'id': id,
      'name': name,
      'completed': false,
      'assignedTo': assignedTo,
      'dueDate': dueDate,
      'repeat': repeat,
      'sortOrder': sortOrder,
    };

    tasks.add(task);

    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'completed': false,
      'assigned_to': assignedTo,
      'due_date': dueDate,
      'repeat': repeat,
      'sort_order': sortOrder,
    };

    try {
      await _supabase.from('tasks').insert(data);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('task_insert', data);
    }

    return task;
  }

  static Future<void> updateTask({
    required String id,
    String? name,
    bool? completed,
    String? assignedTo,
    bool updateAssignedTo = false,
    String? dueDate,
    bool updateDueDate = false,
    String? repeat,
  }) async {
    if (householdId == null) return;

    final updates = <String, dynamic>{};

    if (name != null) {
      updates['name'] = name;
    }

    if (completed != null) {
      updates['completed'] = completed;
    }

    if (updateAssignedTo) {
      updates['assigned_to'] = assignedTo;
    }

    if (updateDueDate) {
      updates['due_date'] = dueDate;
    }

    if (repeat != null) {
      updates['repeat'] = repeat;
    }

    if (updates.isEmpty) {
      return;
    }

    final index = tasks.indexWhere((task) => task['id']?.toString() == id);

    if (index != -1) {
      if (name != null) {
        tasks[index]['name'] = name;
      }

      if (completed != null) {
        tasks[index]['completed'] = completed;
      }

      if (updateAssignedTo) {
        tasks[index]['assignedTo'] = assignedTo;
      }

      if (updateDueDate) {
        tasks[index]['dueDate'] = dueDate;
      }

      if (repeat != null) {
        tasks[index]['repeat'] = repeat;
      }
    }

    _notifyAndCache();

    try {
      await _supabase
          .from('tasks')
          .update(updates)
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('task_update', {'id': id, 'updates': updates});
    }
  }

  static Future<void> deleteTask(String id) async {
    if (householdId == null) return;

    tasks.removeWhere((task) => task['id']?.toString() == id);

    await _saveTaskOrder();

    _notifyAndCache();

    try {
      await _supabase
          .from('tasks')
          .delete()
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('task_delete', {'id': id});
    }
  }

  // ============================================================
  // SHOPPING
  // ============================================================

  static Future<void> addShoppingItem({
    required String name,
    int quantity = 1,
  }) async {
    if (householdId == null) return;

    final id = _newId();

    shoppingItems.add({
      'id': id,
      'name': name,
      'completed': false,
      'quantity': quantity,
      'claimedBy': null,
    });

    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'completed': false,
      'quantity': quantity,
      'claimed_by': null,
    };

    try {
      await _supabase.from('shopping_items').insert(data);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('shopping_insert', data);
    }
  }

  static Future<void> updateShoppingItem({
    required String id,
    bool? completed,
    int? quantity,
    String? claimedBy,
    bool clearClaimedBy = false,
  }) async {
    if (householdId == null) return;

    final updates = <String, dynamic>{};

    if (completed != null) {
      updates['completed'] = completed;
    }

    if (quantity != null) {
      updates['quantity'] = quantity;
    }

    if (clearClaimedBy) {
      updates['claimed_by'] = null;
    } else if (claimedBy != null) {
      updates['claimed_by'] = claimedBy;
    }

    if (updates.isEmpty) {
      return;
    }

    final index = shoppingItems.indexWhere(
      (item) => item['id']?.toString() == id,
    );

    if (index != -1) {
      if (completed != null) {
        shoppingItems[index]['completed'] = completed;
      }

      if (quantity != null) {
        shoppingItems[index]['quantity'] = quantity;
      }

      if (clearClaimedBy) {
        shoppingItems[index]['claimedBy'] = null;
      } else if (claimedBy != null) {
        shoppingItems[index]['claimedBy'] = claimedBy;
      }
    }

    _notifyAndCache();

    try {
      await _supabase
          .from('shopping_items')
          .update(updates)
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('shopping_update', {'id': id, 'updates': updates});
    }
  }

  static Future<void> deleteShoppingItem(String id) async {
    if (householdId == null) return;

    shoppingItems.removeWhere((item) => item['id']?.toString() == id);

    _notifyAndCache();

    try {
      await _supabase
          .from('shopping_items')
          .delete()
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('shopping_delete', {'id': id});
    }
  }

  // ============================================================
  // CHAT
  // ============================================================

  static Future<Map<String, dynamic>?> addChatMessage({
    required String text,
    required String senderId,
    String? replyTo,
  }) async {
    if (householdId == null) {
      return null;
    }

    final id = _newId();
    final timestamp = DateTime.now().toIso8601String();

    final message = {
      'id': id,
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp,
      'edited': false,
      'replyTo': replyTo,
    };

    chatMessages.add(message);

    chatMessages.sort((a, b) {
      return (a['timestamp']?.toString() ?? '').compareTo(
        b['timestamp']?.toString() ?? '',
      );
    });

    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'text': text,
      'sender_id': senderId,
      'timestamp': timestamp,
      'edited': false,
      'reply_to': replyTo,
    };

    try {
      await _supabase.from('chat_messages').insert(data);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('chat_insert', data);
    }

    return message;
  }

  static Future<void> updateChatMessage({
    required String id,
    required String text,
  }) async {
    if (householdId == null) return;

    final index = chatMessages.indexWhere(
      (message) => message['id']?.toString() == id,
    );

    if (index != -1) {
      chatMessages[index]['text'] = text;
      chatMessages[index]['edited'] = true;
    }

    _notifyAndCache();

    final updates = {'text': text, 'edited': true};

    try {
      await _supabase
          .from('chat_messages')
          .update(updates)
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('chat_update', {'id': id, 'updates': updates});
    }
  }

  static Future<void> deleteChatMessage(String id) async {
    if (householdId == null) return;

    chatMessages.removeWhere((message) => message['id']?.toString() == id);

    for (final message in chatMessages) {
      if (message['replyTo']?.toString() == id) {
        message['replyTo'] = null;
      }
    }

    _notifyAndCache();

    try {
      await _supabase
          .from('chat_messages')
          .update({'reply_to': null})
          .eq('reply_to', id)
          .eq('household_id', householdId!);

      await _supabase
          .from('chat_messages')
          .delete()
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;

      await _queueOperation('chat_delete', {'id': id});
    }
  }

  // ============================================================
  // CURRENT MEMBER
  // ============================================================

  static Future<void> setCurrentMember(String? id) async {
    currentMemberId = id;

    if (id == null) {
      await _prefs?.remove('currentMemberId');
    } else {
      await _prefs?.setString('currentMemberId', id);
    }

    version.value++;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static int get currentMemberTaskCount {
    final member = currentMember;

    if (member == null) {
      return 0;
    }

    return tasks.where((task) {
      return task['assignedTo'] == member.id && task['completed'] == false;
    }).length;
  }

  static int get openShoppingItemCount {
    return shoppingItems.where((item) {
      return item['completed'] == false;
    }).length;
  }

  static int get currentMemberShoppingItemCount {
    final member = currentMember;

    if (member == null) {
      return 0;
    }

    return shoppingItems.where((item) {
      return item['claimedBy'] == member.id && item['completed'] == false;
    }).length;
  }

  static List<Map<String, dynamic>> get currentMemberShoppingItems {
    final member = currentMember;

    if (member == null) {
      return [];
    }

    return shoppingItems.where((item) {
      return item['claimedBy'] == member.id && item['completed'] == false;
    }).toList();
  }

  static List<Map<String, dynamic>> get currentMemberTasks {
    final member = currentMember;

    if (member == null) {
      return [];
    }

    return tasks.where((task) {
      return task['assignedTo'] == member.id && task['completed'] == false;
    }).toList();
  }

  static int get memberCount => members.length;

  static Map<String, dynamic>? get latestChatMessage {
    if (chatMessages.isEmpty) {
      return null;
    }

    return chatMessages.last;
  }

  // ============================================================
  // PUBLIC SAVE
  // ============================================================

  static Future<void> save() async {
    await _saveCache();

    if (currentMemberId != null) {
      await _prefs?.setString('currentMemberId', currentMemberId!);
    } else {
      await _prefs?.remove('currentMemberId');
    }

    version.value++;
  }
}
