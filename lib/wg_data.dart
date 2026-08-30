import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications/notification_preferences.dart';
import 'notifications/notification_service.dart';

class WGMember {
  final String id;
  final String name;
  final int colorIndex;
  final bool isAdmin;

  const WGMember({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.isAdmin = false,
  });
}

class WGData {
  static final List<WGMember> members = [];
  static final List<Map<String, dynamic>> shoppingItems = [];
  static final List<Map<String, dynamic>> tasks = [];
  static final List<Map<String, dynamic>> chatMessages = [];
  static final List<Map<String, dynamic>> expenses = [];
  static final List<String> expenseCategories = [];
  static List<Map<String, dynamic>> _pendingOperations = [];

  static String? householdId;
  static String? currentMemberId;
  static String? _householdName;
  static String? _inviteCode;

  static int _unreadMessageCount = 0;
  static String? _lastReadTimestamp;

  static NotificationPreferences? _notificationPrefs;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static final SupabaseClient _supabase = Supabase.instance.client;

  static SharedPreferences? _prefs;

  static RealtimeChannel? _realtimeChannel;

  static Future<void>? _initializationFuture;
  static Future<void>? _syncFuture;

  static Timer? _cacheSaveTimer;

  static final Set<String> _notifiedTaskDueToday = {};

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

  static const List<String> defaultExpenseCategories = [
    'Lebensmittel',
    'Nebenkosten',
    'Miete',
    'Freizeit',
    'Sonstiges',
  ];

  static List<String> get allExpenseCategories {
    final combined = List<String>.from(defaultExpenseCategories);

    for (final cat in expenseCategories) {
      if (!combined.contains(cat)) {
        combined.add(cat);
      }
    }

    return combined;
  }

  static bool get isOnline => _isOnline;

  static Future<String?> testConnection() async {
    try {
      await _supabase
          .from('households')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 8));

      return null;
    } catch (error) {
      return _classifyError(error).error;
    }
  }
  static bool get hasPendingOperations => _readPendingOperations().isNotEmpty;

  static String? get householdName => _householdName;
  static String? get inviteCode => _inviteCode;
  static int get unreadMessageCount => _unreadMessageCount;
  static bool get isAdmin => currentMember?.isAdmin ?? false;

  static double get totalExpenses {
    var total = 0.0;

    for (final expense in expenses) {
      if (expense['excludeFromBalance'] == true) continue;

      final amount = double.tryParse(
            expense['amount']?.toString() ?? '',
          ) ??
          0.0;

      total += amount;
    }

    return total;
  }

  static double get totalExpensesIncludingExcluded {
    var total = 0.0;

    for (final expense in expenses) {
      final amount = double.tryParse(
            expense['amount']?.toString() ?? '',
          ) ??
          0.0;

      total += amount;
    }

    return total;
  }

  static Map<String, double> get expensesByMember {
    final result = <String, double>{};

    for (final member in members) {
      result[member.id] = 0.0;
    }

    for (final expense in expenses) {
      if (expense['excludeFromBalance'] == true) continue;

      final paidBy = expense['paidBy']?.toString();

      if (paidBy != null && result.containsKey(paidBy)) {
        final amount = double.tryParse(
              expense['amount']?.toString() ?? '',
            ) ??
            0.0;

        result[paidBy] = (result[paidBy] ?? 0.0) + amount;
      }
    }

    return result;
  }

  static double get currentMemberExpenses {
    final memberId = currentMemberId;

    if (memberId == null) return 0.0;

    return expensesByMember[memberId] ?? 0.0;
  }

  static double get perPersonShare {
    if (members.isEmpty) return 0.0;

    return totalExpenses / members.length;
  }

  static double get currentMemberBalance {
    final share = perPersonShare;
    final paid = currentMemberExpenses;

    return paid - share;
  }

  static void setNotificationPreferences(NotificationPreferences prefs) {
    _notificationPrefs = prefs;
  }

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

  static String? resolveReferenceDescription(
    String? referenceId,
    String? referenceType,
  ) {
    if (referenceId == null || referenceType == null) {
      return null;
    }

    switch (referenceType) {
      case 'task':
        for (final task in tasks) {
          if (task['id']?.toString() == referenceId) {
            return task['name']?.toString() ?? task['title']?.toString() ?? task['text']?.toString();
          }
        }

        return 'Aufgabe';
      case 'shopping_item':
        for (final item in shoppingItems) {
          if (item['id']?.toString() == referenceId) {
            return item['name']?.toString() ?? item['text']?.toString();
          }
        }

        return 'Einkauf';
      default:
        return null;
    }
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

  static void _loadPendingOperations() {
    if (_prefs == null) {
      _pendingOperations = [];
      return;
    }

    try {
      final raw = _prefs!.getString(_pendingOperationsKey);

      if (raw == null || raw.isEmpty) {
        _pendingOperations = [];
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        _pendingOperations = [];
        return;
      }

      _pendingOperations = decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (error) {
      debugPrint('Could not load pending operations: $error');
      _pendingOperations = [];
    }
  }

  static Future<void> _initializeInternal() async {
    final stopwatch = Stopwatch()..start();

    debugPrint('WGData startup: begin');

    _prefs ??= await SharedPreferences.getInstance();

    debugPrint(
      'WGData startup: SharedPreferences '
      '${stopwatch.elapsedMilliseconds}ms',
    );

    final prefs = _prefs!;

    householdId = prefs.getString('householdId');
    currentMemberId = prefs.getString('currentMemberId');
    _householdName = prefs.getString('householdName');
    _inviteCode = prefs.getString('inviteCode');
    _lastReadTimestamp = prefs.getString('wg_last_read_$householdId');

    _loadCache();
    _loadPendingOperations();

    debugPrint(
      'WGData startup: cache loaded '
      '${stopwatch.elapsedMilliseconds}ms',
    );

    version.value++;

    // ------------------------------------------------------------
    // Existing household
    // ------------------------------------------------------------
    //
    // Nothing network-related belongs on the startup critical path.
    //
    if (householdId != null) {
      unawaited(_subscribeToRealtime());
      unawaited(_syncOnline());

      debugPrint(
        'WGData startup: initialization finished '
        '${stopwatch.elapsedMilliseconds}ms',
      );

      return;
    }

     // ------------------------------------------------------------
    // First installation — no household yet.
    // ------------------------------------------------------------
    //
    // The user must create or join a flatshare via the RegisterPage.
    // We do NOT auto-create a household here anymore.
    //
    debugPrint(
      'WGData startup: no household found, '
      'waiting for user to create/join '
      '${stopwatch.elapsedMilliseconds}ms',
    );
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
              isAdmin: row['isAdmin'] as bool? ?? false,
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

      expenses.clear();

      final cachedExpenses = cached['expenses'];

      if (cachedExpenses is List) {
        for (final row in cachedExpenses) {
          if (row is Map) {
            expenses.add(Map<String, dynamic>.from(row));
          }
        }
      }

      expenseCategories.clear();
      final cachedCategories = cached['expenseCategories'];

      if (cachedCategories is List) {
        for (final cat in cachedCategories) {
          if (cat is String) {
            expenseCategories.add(cat);
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
        'householdName': _householdName,
        'inviteCode': _inviteCode,
        'members': members
            .map(
              (member) => {
                'id': member.id,
                'name': member.name,
                'colorIndex': member.colorIndex,
                'isAdmin': member.isAdmin,
              },
            )
            .toList(),
        'tasks': tasks.map(Map<String, dynamic>.from).toList(),
        'shoppingItems': shoppingItems.map(Map<String, dynamic>.from).toList(),
        'chatMessages': chatMessages.map(Map<String, dynamic>.from).toList(),
        'expenses': expenses.map(Map<String, dynamic>.from).toList(),
        'expenseCategories': List<String>.from(expenseCategories),
      };

      await _prefs!.setString(_cacheKey, jsonEncode(data));
    } catch (error) {
      debugPrint('Could not save local cache: $error');
    }
  }

  static void _notifyAndCache() {
    version.value++;

    _cacheSaveTimer?.cancel();

    _cacheSaveTimer = Timer(const Duration(milliseconds: 250), () {
      _cacheSaveTimer = null;
      unawaited(_saveCache());
    });
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
    return _pendingOperations;
  }

  static Future<void> _writePendingOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    _pendingOperations = operations;

    if (_prefs == null) {
      return;
    }

    await _prefs!.setString(
      _pendingOperationsKey,
      jsonEncode(_pendingOperations),
    );
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

      case 'expense_insert':
        await _supabase.from('expenses').insert(data);
        break;

      case 'expense_update':
        await _supabase
            .from('expenses')
            .update(Map<String, dynamic>.from(data['updates'] as Map))
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'expense_delete':
        await _supabase
            .from('expenses')
            .delete()
            .eq('id', data['id'])
            .eq('household_id', householdId!);
        break;

      case 'expense_category_insert':
        await _supabase.from('expense_categories').insert(data);
        break;

      case 'expense_category_delete':
        await _supabase
            .from('expense_categories')
            .delete()
            .eq('household_id', householdId!)
            .eq('name', data['name']);
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
        _loadHouseholdInfo(),
        _loadMembers(),
        _loadTasks(),
        _loadShoppingItems(),
        _loadChatMessages(),
        _loadExpenses(),
        _loadExpenseCategories(),
      ]).timeout(const Duration(seconds: 8));

      _isOnline = true;

      await _saveCache();

      _checkDueTodayTasks();

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

    // ------------------------------------------------------------
    // EXPENSES
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'expenses',
      callback: (payload) {
        _deferRealtime(() {
          _handleExpensesRealtime(payload, currentHouseholdId);
        });
      },
    );

    // ------------------------------------------------------------
    // EXPENSE_CATEGORIES
    // ------------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'expense_categories',
      callback: (payload) {
        _deferRealtime(() {
          _handleExpenseCategoriesRealtime(payload);
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
  static void _sortChatMessages() {
    chatMessages.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '');

      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '');

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;

      return aTime.compareTo(bTime);
    });
  }

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

        final newMember = WGMember(
          id: id,
          name: newRecord['name']?.toString() ?? '',
          colorIndex: newRecord['color_index'] as int? ?? 0,
          isAdmin: newRecord['is_admin'] as bool? ?? false,
        );

        members.add(newMember);

        _triggerMemberJoinedNotification(newMember);
        break;

      case PostgresChangeEvent.update:
        final index = members.indexWhere((member) => member.id == id);

        final updated = WGMember(
          id: id,
          name: newRecord['name']?.toString() ?? '',
          colorIndex: newRecord['color_index'] as int? ?? 0,
          isAdmin: newRecord['is_admin'] as bool? ?? false,
        );

        if (index == -1) {
          members.add(updated);
        } else {
          members[index] = updated;
        }
        break;

      case PostgresChangeEvent.delete:
        final deletedMember = members.firstWhere(
          (member) => member.id == id,
          orElse: () => const WGMember(id: '', name: '', colorIndex: 0),
        );

        members.removeWhere((member) => member.id == id);

        if (currentMemberId == id) {
          currentMemberId = null;

          unawaited(_prefs?.remove('currentMemberId'));
        }

        if (deletedMember.id.isNotEmpty) {
          _triggerMemberLeftNotification(deletedMember);
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

        final newTask = _taskFromRow(newRecord);
        tasks.add(newTask);

        _triggerTaskAssignedNotification(newTask);
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
          final oldAssignedTo = tasks[index]['assignedTo']?.toString();
          final newAssignedTo = newRecord['assigned_to']?.toString();

          tasks[index] = updated;

          if (newAssignedTo != oldAssignedTo) {
            _triggerTaskAssignedNotification(updated);
          }
        }
        break;

      case PostgresChangeEvent.delete:
        tasks.removeWhere((task) => task['id']?.toString() == id);
        break;

      default:
        return;
    }

    _sortTasksLocally();
    _sortChatMessages();
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

        final newItem = _shoppingFromRow(newRecord);
        shoppingItems.add(newItem);

        _triggerShoppingNotification(newItem);
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

        final newMessage = _chatFromRow(newRecord);
        chatMessages.add(newMessage);

        _handleNewChatMessage(newMessage);
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

  static void _handleExpensesRealtime(
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
        if (expenses.any((e) => e['id']?.toString() == id)) {
          return;
        }

        expenses.add(_expenseFromRow(newRecord));
        _notifyAndCache();
        break;

      case PostgresChangeEvent.update:
        final index = expenses.indexWhere(
          (e) => e['id']?.toString() == id,
        );

        final updated = _expenseFromRow(newRecord);

        if (index == -1) {
          expenses.add(updated);
        } else {
          expenses[index] = updated;
        }

        _notifyAndCache();
        break;

      case PostgresChangeEvent.delete:
        expenses.removeWhere((e) => e['id']?.toString() == id);
        _notifyAndCache();
        break;

      default:
        return;
    }
  }

  static void _handleExpenseCategoriesRealtime(
    PostgresChangePayload payload,
  ) {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final name = newRecord['name']?.toString();

        if (name != null && !expenseCategories.contains(name)) {
          expenseCategories.add(name);
          _notifyAndCache();
        }
        break;

      case PostgresChangeEvent.delete:
        final name = oldRecord['name']?.toString();

        if (name != null && expenseCategories.contains(name)) {
          expenseCategories.remove(name);
          _notifyAndCache();
        }
        break;

      default:
        return;
    }
  }

  // ============================================================
  // UNREAD MESSAGE TRACKING
  // ============================================================

  static Future<void> _saveLastReadTimestamp(String timestamp) async {
    _lastReadTimestamp = timestamp;

    if (_prefs == null || householdId == null) {
      return;
    }

    try {
      await _prefs!.setString(
        'wg_last_read_$householdId',
        timestamp,
      );
    } catch (error) {
      debugPrint('Could not save last read timestamp: $error');
    }
  }

   static Future<void> markMessagesRead() async {
    final lastMessage = chatMessages.isNotEmpty
        ? chatMessages.last['timestamp']?.toString()
        : null;

    if (lastMessage != null) {
      _lastReadTimestamp = lastMessage;
    }

    _unreadMessageCount = 0;

    if (lastMessage != null) {
      await _saveLastReadTimestamp(lastMessage);
    }
  }

  static void _recalculateUnreadCount() {
    final lastRead =
        _lastReadTimestamp != null
            ? DateTime.tryParse(_lastReadTimestamp!)
            : null;

    _unreadMessageCount = chatMessages.where((message) {
      final senderId = message['senderId']?.toString();

      if (senderId == currentMemberId) return false;

      if (lastRead == null) return true;

      final messageTime = DateTime.tryParse(
        message['timestamp']?.toString() ?? '',
      );

      if (messageTime == null) return false;

      return messageTime.isAfter(lastRead);
    }).length;
  }

  static void _handleNewChatMessage(Map<String, dynamic> message) {
    final senderId = message['senderId']?.toString();

    if (senderId != currentMemberId && _lastReadTimestamp != null) {
      final messageTime = DateTime.tryParse(
        message['timestamp']?.toString() ?? '',
      );

      final lastRead = DateTime.tryParse(_lastReadTimestamp!);

      if (lastRead == null ||
          (messageTime != null && messageTime.isAfter(lastRead))) {
        _unreadMessageCount++;
      }
    } else if (senderId != currentMemberId) {
      _unreadMessageCount++;
    }

    _triggerChatNotification(message);
  }

  // ============================================================
  // NOTIFICATION TRIGGERS
  // ============================================================

  static WGMember? _findMemberById(String? id) {
    if (id == null) {
      return null;
    }

    for (final member in members) {
      if (member.id == id) {
        return member;
      }
    }

    return null;
  }

  static void _triggerChatNotification(Map<String, dynamic> message) {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.chat) {
      return;
    }

    final senderId = message['senderId']?.toString();
    final sender = _findMemberById(senderId);

    if (sender == null || senderId == currentMemberId) {
      return;
    }

    final text = message['text']?.toString() ?? '';

    if (text.isEmpty) {
      return;
    }

    NotificationService.instance.showChatMessageNotification(
      senderName: sender.name,
      messageText: text,
    );
  }

  static void _triggerShoppingNotification(Map<String, dynamic> item) {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.shopping) {
      return;
    }

    final currentMember = WGData.currentMember;

    if (currentMember == null) {
      return;
    }

    final addedBy = item['addedBy'] as String?;

    if (addedBy != null && addedBy != currentMember.id) {
      final member = _findMemberById(addedBy);

      if (member != null) {
        NotificationService.instance.showShoppingNotification(
          personName: member.name,
          itemName: item['name']?.toString() ?? '',
        );
      }
    }
  }

  static void _triggerMemberJoinedNotification(WGMember member) {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.general) {
      return;
    }

    final currentMember = WGData.currentMember;

    if (currentMember == null ||
        member.id == currentMember.id) {
      return;
    }

    NotificationService.instance.showMemberJoinedNotification(
      memberName: member.name,
    );
  }

  static void _triggerMemberLeftNotification(WGMember member) {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.general) {
      return;
    }

    final currentMember = WGData.currentMember;

    if (currentMember == null ||
        member.id == currentMember.id) {
      return;
    }

    NotificationService.instance.showMemberLeftNotification(
      memberName: member.name,
    );
  }

  static void _triggerTaskAssignedNotification(
    Map<String, dynamic> task,
  ) {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.taskAssignments) {
      return;
    }

    final currentMember = WGData.currentMember;

    if (currentMember == null) {
      return;
    }

    final assignedTo = task['assignedTo']?.toString();

    if (assignedTo != currentMember.id) {
      return;
    }

    final memberId = task['addedBy'] as String?;

    final assigner = memberId != null && memberId != currentMember.id
        ? _findMemberById(memberId)
        : null;

    NotificationService.instance.showTaskAssignedNotification(
      assigneeName: currentMember.name,
      taskName: task['name']?.toString() ?? '',
      assignerName: assigner?.name,
    );
  }

  static void _checkDueTodayTasks() {
    final prefs = _notificationPrefs;

    if (prefs == null || !prefs.taskDueToday) {
      return;
    }

    final currentMember = WGData.currentMember;

    if (currentMember == null) {
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final task in tasks) {
      final taskId = task['id']?.toString();

      if (taskId == null) continue;

      final completed = task['completed'] == true;

      if (completed) continue;

      final dueDateValue = task['dueDate']?.toString();

      if (dueDateValue == null) continue;

      final dueDate = DateTime.tryParse(dueDateValue);

      if (dueDate == null) continue;

      final dueDateOnly =
          DateTime(dueDate.year, dueDate.month, dueDate.day);

      if (dueDateOnly != todayDate) continue;

      final assignedTo = task['assignedTo']?.toString();
      final isAssignedToCurrentUser = assignedTo == currentMember.id ||
          assignedTo == null ||
          assignedTo == 'nobody';

      if (!isAssignedToCurrentUser) continue;

      if (_notifiedTaskDueToday.contains(taskId)) continue;

      _notifiedTaskDueToday.add(taskId);

      NotificationService.instance.showTaskDueTodayNotification(
        taskId: taskId,
        taskName: task['name']?.toString() ?? 'Aufgabe',
      );
    }
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
      'addedBy': row['added_by'],
    };
  }

  static Map<String, dynamic> _shoppingFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'completed': row['completed'] ?? false,
      'quantity': row['quantity'] ?? 1,
      'claimedBy': row['claimed_by'],
      'addedBy': row['added_by'],
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
      'referenceId': row['reference_id'],
      'referenceType': row['reference_type'],
    };
  }

  static Map<String, dynamic> _expenseFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'description': row['description'],
      'amount': row['amount'],
      'paidBy': row['paid_by'],
      'category': row['category'],
      'excludeFromBalance': row['exclude_from_balance'] == true,
      'createdAt': row['created_at'],
    };
  }

  // ============================================================
  // SERVER LOAD
  // ============================================================

  static Future<void> _loadHouseholdInfo() async {
    if (householdId == null) return;

    try {
      final response = await _supabase
          .from('households')
          .select('name, invite_code')
          .eq('id', householdId!)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response != null) {
        _householdName = response['name']?.toString();
        _inviteCode = response['invite_code']?.toString();

        if (_householdName != null) {
          await _prefs?.setString('householdName', _householdName!);
        }

        if (_inviteCode != null) {
          await _prefs?.setString('inviteCode', _inviteCode!);
        }
      }
    } catch (error) {
      debugPrint('Could not load household info: $error');
    }
  }

  static Future<void> _loadExpenses() async {
    if (householdId == null) return;

    try {
      final response = await _supabase
          .from('expenses')
          .select('*')
          .eq('household_id', householdId!)
          .order('created_at', ascending: false);

      final hasPendingExpenseInserts = _pendingOperations.any(
        (op) => op['type']?.toString() == 'expense_insert',
      );

      if (response.isEmpty && hasPendingExpenseInserts) {
        debugPrint(
          'Expenses: keeping local data '
          '(server empty but pending inserts exist).',
        );

        return;
      }

      expenses.clear();

      for (final row in response) {
        expenses.add(_expenseFromRow(row));
      }
    } catch (error) {
      debugPrint('Could not load expenses: $error');
    }
  }

  static Future<void> _loadExpenseCategories() async {
    if (householdId == null) return;

    try {
      final response = await _supabase
          .from('expense_categories')
          .select('name')
          .eq('household_id', householdId!)
          .order('name');

      expenseCategories.clear();

      for (final row in response) {
        final name = row['name']?.toString();

        if (name != null && !expenseCategories.contains(name)) {
          expenseCategories.add(name);
        }
      }
    } catch (error) {
      debugPrint('Could not load expense categories: $error');
    }
  }

  static Future<void> _loadMembers() async {
    if (householdId == null) return;

    final response = await _supabase
        .from('members')
        .select('*')
        .eq('household_id', householdId!)
        .order('created_at');

    members.clear();

    for (final row in response) {
      members.add(
        WGMember(
          id: row['id'] as String,
          name: row['name'] as String,
          colorIndex: row['color_index'] as int? ?? 0,
          isAdmin: row['is_admin'] as bool? ?? false,
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
        .select('*')
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
        .select('*')
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
        .select('*')
        .eq('household_id', householdId!)
        .order('timestamp');

    chatMessages.clear();

    for (final row in response) {
      chatMessages.add(_chatFromRow(row));
    }

    _recalculateUnreadCount();
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
    bool isAdmin = false,
  }) async {
    if (householdId == null) {
      return null;
    }

    final id = _newId();

    final member = WGMember(
      id: id,
      name: name,
      colorIndex: colorIndex,
      isAdmin: isAdmin,
    );

    members.add(member);
    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'color_index': colorIndex,
      'is_admin': isAdmin,
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
      final existing = members[index];
      members[index] = WGMember(
        id: id,
        name: name,
        colorIndex: colorIndex,
        isAdmin: existing.isAdmin,
      );

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
      'addedBy': currentMemberId,
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
      'added_by': currentMemberId,
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
    String? addedBy,
  }) async {
    if (householdId == null) return;

    final id = _newId();

    final item = {
      'id': id,
      'name': name,
      'completed': false,
      'quantity': quantity,
      'claimedBy': null,
      'addedBy': addedBy ?? currentMemberId,
    };

    shoppingItems.add(item);

    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'name': name,
      'completed': false,
      'quantity': quantity,
      'claimed_by': null,
      'added_by': addedBy ?? currentMemberId,
    };

    try {
      await _supabase.from('shopping_items').insert(data);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('shopping_insert', data);
    }

    _triggerShoppingNotification(item);
  }

  // ============================================================
  // EXPENSES (WG-Kasse)
  // ============================================================

  static Future<void> addExpense({
    required String description,
    required double amount,
    String? paidBy,
    String? category,
    bool excludeFromBalance = false,
  }) async {
    if (householdId == null) return;

    final id = _newId();
    final timestamp = DateTime.now().toIso8601String();

    final expense = {
      'id': id,
      'description': description,
      'amount': amount,
      'paidBy': paidBy ?? currentMemberId,
      'category': category,
      'excludeFromBalance': excludeFromBalance,
      'createdAt': timestamp,
    };

    expenses.insert(0, expense);

    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'description': description,
      'amount': amount,
      'paid_by': paidBy ?? currentMemberId,
      'category': category,
      'exclude_from_balance': excludeFromBalance,
      'created_at': timestamp,
    };

        try {
          await _supabase.from('expenses').insert(data);
          _isOnline = true;
        } catch (error) {
          debugPrint(
            'Expense insert to Supabase failed: $error '
            '(table may lack RLS policy or required columns). '
            'Queuing for retry.',
          );
          _isOnline = false;
          await _queueOperation('expense_insert', data);
        }
  }

  static Future<void> updateExpense({
    required String id,
    String? description,
    double? amount,
    String? paidBy,
    String? category,
    bool? excludeFromBalance,
  }) async {
    if (householdId == null) return;

    final index = expenses.indexWhere(
      (e) => e['id']?.toString() == id,
    );

    if (index == -1) return;

    final updates = <String, dynamic>{};

    if (description != null) {
      expenses[index]['description'] = description;
      updates['description'] = description;
    }

    if (amount != null) {
      expenses[index]['amount'] = amount;
      updates['amount'] = amount;
    }

    if (paidBy != null) {
      expenses[index]['paidBy'] = paidBy;
      updates['paid_by'] = paidBy;
    }

    if (category != null) {
      expenses[index]['category'] = category;
      updates['category'] = category;
    }

    if (excludeFromBalance != null) {
      expenses[index]['excludeFromBalance'] = excludeFromBalance;
      updates['exclude_from_balance'] = excludeFromBalance;
    }

    if (updates.isEmpty) return;

    _notifyAndCache();

    try {
      await _supabase
          .from('expenses')
          .update(updates)
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('expense_update', {
        'id': id,
        'updates': updates,
      });
    }
  }

  static Future<void> deleteExpense(String id) async {
    if (householdId == null) return;

    final index = expenses.indexWhere(
      (e) => e['id']?.toString() == id,
    );

    if (index == -1) return;

    expenses.removeAt(index);

    _notifyAndCache();

    try {
      await _supabase
          .from('expenses')
          .delete()
          .eq('id', id)
          .eq('household_id', householdId!);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('expense_delete', {'id': id});
    }
  }

  static Future<void> addExpenseCategory(String name) async {
    final trimmed = name.trim();

    if (trimmed.isEmpty || expenseCategories.contains(trimmed)) return;

    expenseCategories.add(trimmed);

    _notifyAndCache();

    if (householdId == null) return;

    try {
      await _supabase.from('expense_categories').insert({
        'household_id': householdId,
        'name': trimmed,
        'is_default': false,
      });

      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('expense_category_insert', {'name': trimmed});
    }
  }

  static Future<void> deleteExpenseCategory(String name) async {
    expenseCategories.remove(name);

    _notifyAndCache();

    if (householdId == null) return;

    try {
      await _supabase
          .from('expense_categories')
          .delete()
          .eq('household_id', householdId!)
          .eq('name', name);

      _isOnline = true;
    } catch (error) {
      _isOnline = false;
    }
  }

  static Map<String, double> expensesByCategoryInDateRange(
    DateTime start,
    DateTime end,
  ) {
    final result = <String, double>{};

    for (final e in expenses) {
      final createdAt = e['createdAt']?.toString();

      if (createdAt == null) continue;

      final date = DateTime.tryParse(createdAt);

      if (date == null) continue;

      if (date.isBefore(start) || date.isAfter(end)) continue;

      final category = e['category']?.toString() ?? 'Sonstiges';
      final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;

      result[category] = (result[category] ?? 0.0) + amount;
    }

    return result;
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
    String? referenceId,
    String? referenceType,
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
      'referenceId': referenceId,
      'referenceType': referenceType,
    };

    chatMessages.add(message);
    _sortChatMessages();
    _notifyAndCache();

    final data = {
      'id': id,
      'household_id': householdId,
      'text': text,
      'sender_id': senderId,
      'timestamp': timestamp,
      'edited': false,
      'reply_to': replyTo,
      'reference_id': referenceId,
      'reference_type': referenceType,
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

    _recalculateUnreadCount();
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
  // HOUSEHOLD MANAGEMENT
  // ============================================================

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buffer = StringBuffer();

    for (var i = 0; i < 6; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }
  static Future<HouseholdJoinResult> createHousehold({
    required String householdName,
    required String memberName,
    required int colorIndex,
  }) async {
    try {
      final code = _generateInviteCode();

      final response = await _supabase
          .from('households')
          .insert({
            'name': householdName,
            'invite_code': code,
          })
          .select('id, name, invite_code')
          .single()
          .timeout(const Duration(seconds: 8));

      householdId = response['id'] as String;
      _householdName = response['name'] as String? ?? householdName;
      _inviteCode = response['invite_code'] as String? ?? code;

      await _prefs?.setString('householdId', householdId!);
      await _prefs?.setString('householdName', _householdName!);
      await _prefs?.setString('inviteCode', _inviteCode!);

      await _prefs?.setString('wg_last_read_$householdId', '');

      final newMember = await addMember(
        name: memberName,
        colorIndex: colorIndex,
        isAdmin: true,
      );

      if (newMember != null) {
        currentMemberId = newMember.id;
        await _prefs?.setString('currentMemberId', newMember.id);
      }

      version.value++;

      unawaited(_subscribeToRealtime());
      unawaited(_syncOnline());

      return const HouseholdJoinResult(success: true);
    } catch (error) {
      debugPrint('Could not create household: $error');

      return _classifyError(error);
    }
  }

  static Future<HouseholdJoinResult> joinHouseholdByInviteCode({
    required String inviteCode,
    required String memberName,
    required int colorIndex,
  }) async {
    final trimmedCode = inviteCode.trim().toUpperCase();

    try {
      final response = await _supabase
          .from('households')
          .select('id, name, invite_code')
          .eq('invite_code', trimmedCode)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) {
        return const HouseholdJoinResult(success: false, error: 'code');
      }

      householdId = response['id'] as String;
      _householdName = response['name'] as String? ?? '';
      _inviteCode = response['invite_code'] as String? ?? trimmedCode;

      await _prefs?.setString('householdId', householdId!);
      await _prefs?.setString('householdName', _householdName!);
      await _prefs?.setString('inviteCode', _inviteCode!);

      _lastReadTimestamp = _prefs?.getString('wg_last_read_$householdId');

      _loadCache();

      final newMember = await addMember(
        name: memberName,
        colorIndex: colorIndex,
        isAdmin: false,
      );

      if (newMember != null) {
        currentMemberId = newMember.id;
        await _prefs?.setString('currentMemberId', newMember.id);
      }

      version.value++;

      unawaited(_subscribeToRealtime());
      unawaited(_syncOnline());

      return const HouseholdJoinResult(success: true);
    } catch (error) {
      debugPrint('Could not join household: $error');

      return _classifyError(error);
    }
  }

  static Future<bool> refreshInviteCode() async {
    if (householdId == null) {
      return false;
    }

    final newCode = _generateInviteCode();

    try {
      await _supabase
          .from('households')
          .update({'invite_code': newCode})
          .eq('id', householdId!)
          .timeout(const Duration(seconds: 8));

      _inviteCode = newCode;

      await _prefs?.setString('inviteCode', newCode);

      _notifyAndCache();

      return true;
    } catch (error) {
      debugPrint('Could not refresh invite code: $error');
      return false;
    }
  }

  static Future<bool> updateHouseholdName(String name) async {
    if (householdId == null) {
      return false;
    }

    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return false;
    }

    try {
      await _supabase
          .from('households')
          .update({'name': trimmedName})
          .eq('id', householdId!)
          .timeout(const Duration(seconds: 8));

      _householdName = trimmedName;

      await _prefs?.setString('householdName', trimmedName);

      _notifyAndCache();

      return true;
    } catch (error) {
      debugPrint('Could not update household name: $error');
      return false;
    }
  }

  static Future<void> setAdmin(String memberId, bool isAdmin) async {
    if (householdId == null) return;

    final index = members.indexWhere((member) => member.id == memberId);

    if (index != -1) {
      final existing = members[index];
      members[index] = WGMember(
        id: existing.id,
        name: existing.name,
        colorIndex: existing.colorIndex,
        isAdmin: isAdmin,
      );

      _notifyAndCache();
    }

    try {
      await _supabase
          .from('members')
          .update({'is_admin': isAdmin})
          .eq('id', memberId)
          .eq('household_id', householdId!);
      _isOnline = true;
    } catch (error) {
      _isOnline = false;
      await _queueOperation('member_update', {
        'id': memberId,
        'updates': {'is_admin': isAdmin},
      });
    }
  }

  static Future<void> leaveHousehold() async {
    householdId = null;
    currentMemberId = null;
    _householdName = null;
    _inviteCode = null;
    _lastReadTimestamp = null;
    _unreadMessageCount = 0;

    members.clear();
    tasks.clear();
    shoppingItems.clear();
    chatMessages.clear();

    await _prefs?.remove('householdId');
    await _prefs?.remove('householdName');
    await _prefs?.remove('inviteCode');
    await _prefs?.remove('currentMemberId');

    version.value++;
  }

  // ============================================================
  // PUBLIC SAVE
  // ============================================================

  static Future<void> save() async {
    _cacheSaveTimer?.cancel();
    _cacheSaveTimer = null;

    await _saveCache();

    if (householdId != null) {
      await _prefs?.setString('householdId', householdId!);
      if (_householdName != null) {
        await _prefs?.setString('householdName', _householdName!);
      }
      if (_inviteCode != null) {
        await _prefs?.setString('inviteCode', _inviteCode!);
      }
    }

    if (currentMemberId != null) {
      await _prefs?.setString('currentMemberId', currentMemberId!);
    } else {
      await _prefs?.remove('currentMemberId');
    }

    if (_lastReadTimestamp != null && householdId != null) {
      await _prefs?.setString('wg_last_read_$householdId', _lastReadTimestamp!);
    }

    version.value++;
  }

  static HouseholdJoinResult _classifyError(Object error) {
    debugPrint('WGData error details: $error');

    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      final code = error.code;

      if (code == '42P01' ||
          code == '42703' ||
          message.contains('invite_code') ||
          message.contains('column') ||
          message.contains('relation') ||
          message.contains('table') ||
          message.contains('does not exist') ||
          message.contains('undefined')) {
        return const HouseholdJoinResult(success: false, error: 'schema');
      }

      if (code == '42501' ||
          message.contains('permission') ||
          message.contains('policy') ||
          message.contains('denied') ||
          message.contains('forbidden') ||
          message.contains('rls') ||
          message.contains('row-level')) {
        return const HouseholdJoinResult(success: false, error: 'permission');
      }
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('host')) {
      return const HouseholdJoinResult(success: false, error: 'network');
    }

    return const HouseholdJoinResult(success: false, error: 'network');
  }
}

class HouseholdJoinResult {
  final bool success;
  final String? error;

  const HouseholdJoinResult({required this.success, this.error});

  static const network = HouseholdJoinResult(success: false, error: 'network');
  static const code = HouseholdJoinResult(success: false, error: 'code');
  static const schema = HouseholdJoinResult(success: false, error: 'schema');
  static const auth = HouseholdJoinResult(success: false, error: 'auth');
}
