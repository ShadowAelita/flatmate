import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static final SupabaseClient _supabase = Supabase.instance.client;

  static const List<Color> memberColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.purple,
  ];

  static String? currentMemberId;

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
  // HOUSEHOLD
  // ============================================================

  static Future<void> _initializeHousehold() async {
    final prefs = await SharedPreferences.getInstance();

    final savedHouseholdId = prefs.getString('householdId');

    if (savedHouseholdId != null) {
      householdId = savedHouseholdId;
      return;
    }

    final response = await _supabase
        .from('households')
        .insert({'name': 'Unsere WG'})
        .select()
        .single();

    householdId = response['id'] as String;

    await prefs.setString('householdId', householdId!);
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> initialize() async {
    await _initializeHousehold();

    final prefs = await SharedPreferences.getInstance();

    final savedCurrentMemberId = prefs.getString('currentMemberId');

    members.clear();
    shoppingItems.clear();
    tasks.clear();
    chatMessages.clear();

    currentMemberId = savedCurrentMemberId;

    await _loadMembers();
    await _loadTasks();

    version.value++;
  }

  // ============================================================
  // MEMBERS
  // ============================================================

  static Future<void> _loadMembers() async {
    if (householdId == null) {
      return;
    }

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

    // If the locally selected member no longer exists,
    // clear the selection.
    if (currentMemberId != null &&
        !members.any((member) => member.id == currentMemberId)) {
      currentMemberId = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentMemberId');
    }
  }

  static Future<WGMember?> addMember({
    required String name,
    required int colorIndex,
  }) async {
    if (householdId == null) {
      return null;
    }

    final response = await _supabase
        .from('members')
        .insert({
          'household_id': householdId,
          'name': name,
          'color_index': colorIndex,
        })
        .select('id, name, color_index')
        .single();

    final member = WGMember(
      id: response['id'] as String,
      name: response['name'] as String,
      colorIndex: response['color_index'] as int? ?? 0,
    );

    members.add(member);

    version.value++;

    return member;
  }

  static Future<void> updateMember({
    required String id,
    required String name,
    required int colorIndex,
  }) async {
    await _supabase
        .from('members')
        .update({'name': name, 'color_index': colorIndex})
        .eq('id', id)
        .eq('household_id', householdId!);

    final index = members.indexWhere((member) => member.id == id);

    if (index != -1) {
      members[index] = WGMember(id: id, name: name, colorIndex: colorIndex);
    }

    version.value++;
  }

  static Future<void> deleteMember(String id) async {
    await _supabase
        .from('members')
        .delete()
        .eq('id', id)
        .eq('household_id', householdId!);

    members.removeWhere((member) => member.id == id);

    if (currentMemberId == id) {
      currentMemberId = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentMemberId');
    }

    // These local references will eventually also be moved
    // to Supabase when we migrate tasks/shopping/chat.
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

    chatMessages.removeWhere((message) => message['senderId'] == id);

    version.value++;
  }
  // ============================================================
  // TASKS
  // ============================================================

  static Future<void> _loadTasks() async {
    if (householdId == null) {
      return;
    }

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
      tasks.add({
        'id': row['id'],
        'name': row['name'],
        'completed': row['completed'] ?? false,
        'assignedTo': row['assigned_to'],
        'dueDate': row['due_date'],
        'repeat': row['repeat'] ?? 'none',
      });
    }
  }

  static Future<Map<String, dynamic>?> addTask({
    required String name,
    String? assignedTo,
    String? dueDate,
    String repeat = 'none',
  }) async {
    if (householdId == null) {
      return null;
    }

    final sortOrder = tasks.length;

    final response = await _supabase
        .from('tasks')
        .insert({
          'household_id': householdId,
          'name': name,
          'completed': false,
          'assigned_to': assignedTo,
          'due_date': dueDate,
          'repeat': repeat,
          'sort_order': sortOrder,
        })
        .select(
          'id, name, completed, assigned_to, due_date, repeat, sort_order',
        )
        .single();

    final task = {
      'id': response['id'],
      'name': response['name'],
      'completed': response['completed'] ?? false,
      'assignedTo': response['assigned_to'],
      'dueDate': response['due_date'],
      'repeat': response['repeat'] ?? 'none',
    };

    tasks.add(task);

    version.value++;

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
    if (householdId == null) {
      return;
    }

    final updates = <String, dynamic>{};

    if (name != null) {
      updates['name'] = name;
    }

    if (completed != null) {
      updates['completed'] = completed;
    }

    // Important:
    // This also sends NULL to Supabase when we want to
    // remove the assignment.
    if (updateAssignedTo) {
      updates['assigned_to'] = assignedTo;
    }

    // Same idea for due dates.
    // This allows us to explicitly clear due_date.
    if (updateDueDate) {
      updates['due_date'] = dueDate;
    }

    if (repeat != null) {
      updates['repeat'] = repeat;
    }

    if (updates.isEmpty) {
      return;
    }

    await _supabase
        .from('tasks')
        .update(updates)
        .eq('id', id)
        .eq('household_id', householdId!);

    final index = tasks.indexWhere((task) => task['id'] == id);

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

    version.value++;
  }

  static Future<void> deleteTask(String id) async {
    if (householdId == null) {
      return;
    }

    await _supabase
        .from('tasks')
        .delete()
        .eq('id', id)
        .eq('household_id', householdId!);

    tasks.removeWhere((task) => task['id'] == id);

    await _saveTaskOrder();

    version.value++;
  }

  static Future<void> updateTaskOrder() async {
    if (householdId == null) {
      return;
    }

    await _saveTaskOrder();

    version.value++;
  }

  static Future<void> _saveTaskOrder() async {
    if (householdId == null) {
      return;
    }

    for (var index = 0; index < tasks.length; index++) {
      final taskId = tasks[index]['id'];

      await _supabase
          .from('tasks')
          .update({'sort_order': index})
          .eq('id', taskId)
          .eq('household_id', householdId!);
    }
  }

  // ============================================================
  // CURRENT MEMBER
  // ============================================================

  static Future<void> setCurrentMember(String? id) async {
    currentMemberId = id;

    final prefs = await SharedPreferences.getInstance();

    if (id == null) {
      await prefs.remove('currentMemberId');
    } else {
      await prefs.setString('currentMemberId', id);
    }

    version.value++;
  }

  // ============================================================
  // EXISTING APP HELPERS
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

  static int get memberCount {
    return members.length;
  }

  static Map<String, dynamic>? get latestChatMessage {
    if (chatMessages.isEmpty) {
      return null;
    }

    return chatMessages.last;
  }

  // ============================================================
  // LEGACY LOCAL SAVE
  // ============================================================
  //
  // We keep this temporarily for tasks/shopping/chat because
  // those are not migrated to Supabase yet.
  //
  // Members are NO LONGER saved here.
  //

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('shoppingItems', jsonEncode(shoppingItems));

    await prefs.setString('chatMessages', jsonEncode(chatMessages));

    if (currentMemberId != null) {
      await prefs.setString('currentMemberId', currentMemberId!);
    } else {
      await prefs.remove('currentMemberId');
    }

    version.value++;
  }
}
