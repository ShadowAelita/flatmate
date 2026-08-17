import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class WGMember {
  final String id;
  final String name;

  const WGMember({required this.id, required this.name});
}

class WGData {
  static final List<WGMember> members = [];
  static final List<Map<String, dynamic>> shoppingItems = [];
  static final List<Map<String, dynamic>> tasks = [];
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static String? currentMemberId;

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

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    bool tasksChanged = false;

    final savedMembers = prefs.getString('members');
    final savedShoppingItems = prefs.getString('shoppingItems');
    final savedTasks = prefs.getString('tasks');
    final savedCurrentMemberId = prefs.getString('currentMemberId');

    members.clear();
    shoppingItems.clear();
    tasks.clear();

    if (savedMembers != null) {
      final decodedMembers = jsonDecode(savedMembers) as List;

      members.addAll(
        decodedMembers.map((member) {
          final data = member as Map<String, dynamic>;

          return WGMember(
            id: data['id'] as String,
            name: data['name'] as String,
          );
        }),
      );
    }

    if (savedShoppingItems != null) {
      final decodedShoppingItems = jsonDecode(savedShoppingItems) as List;

      shoppingItems.addAll(
        decodedShoppingItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }),
      );
    }

    if (savedTasks != null) {
      final decodedTasks = jsonDecode(savedTasks) as List;

      tasks.addAll(
        decodedTasks.map((task) {
          final data = Map<String, dynamic>.from(task as Map);

          if (data['id'] == null) {
            data['id'] = DateTime.now().microsecondsSinceEpoch.toString();
            tasksChanged = true;
          }

          return data;
        }),
      );
    }

    currentMemberId = savedCurrentMemberId;

    if (tasksChanged) {
      await save();
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final membersJson = members.map((member) {
      return {'id': member.id, 'name': member.name};
    }).toList();

    await prefs.setString('members', jsonEncode(membersJson));

    await prefs.setString('shoppingItems', jsonEncode(shoppingItems));

    await prefs.setString('tasks', jsonEncode(tasks));

    if (currentMemberId != null) {
      await prefs.setString('currentMemberId', currentMemberId!);
    } else {
      await prefs.remove('currentMemberId');
    }
    version.value++;
  }
}
