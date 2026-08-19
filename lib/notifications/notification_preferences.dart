import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences extends ChangeNotifier {
  static const String _taskAssignmentsKey =
      'notifications_task_assignments';

  static const String _taskDueTodayKey =
      'notifications_task_due_today';

  static const String _shoppingKey =
      'notifications_shopping';

  static const String _chatKey =
      'notifications_chat';

  static const String _generalKey =
      'notifications_general';

  SharedPreferences? _prefs;

  bool _taskAssignments = true;
  bool _taskDueToday = true;
  bool _shopping = false;
  bool _chat = true;
  bool _general = true;

  bool get taskAssignments => _taskAssignments;
  bool get taskDueToday => _taskDueToday;
  bool get shopping => _shopping;
  bool get chat => _chat;
  bool get general => _general;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    _taskAssignments =
        _prefs!.getBool(_taskAssignmentsKey) ?? true;

    _taskDueToday =
        _prefs!.getBool(_taskDueTodayKey) ?? true;

    _shopping =
        _prefs!.getBool(_shoppingKey) ?? false;

    _chat =
        _prefs!.getBool(_chatKey) ?? true;

    _general =
        _prefs!.getBool(_generalKey) ?? true;

    notifyListeners();
  }

  Future<void> setTaskAssignments(bool value) async {
    _taskAssignments = value;
    notifyListeners();

    await _prefs?.setBool(
      _taskAssignmentsKey,
      value,
    );
  }

  Future<void> setTaskDueToday(bool value) async {
    _taskDueToday = value;
    notifyListeners();

    await _prefs?.setBool(
      _taskDueTodayKey,
      value,
    );
  }

  Future<void> setShopping(bool value) async {
    _shopping = value;
    notifyListeners();

    await _prefs?.setBool(
      _shoppingKey,
      value,
    );
  }

  Future<void> setChat(bool value) async {
    _chat = value;
    notifyListeners();

    await _prefs?.setBool(
      _chatKey,
      value,
    );
  }

  Future<void> setGeneral(bool value) async {
    _general = value;
    notifyListeners();

    await _prefs?.setBool(
      _generalKey,
      value,
    );
  }
}
