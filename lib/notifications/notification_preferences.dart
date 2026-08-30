import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences extends ChangeNotifier {
  static const String _taskAssignmentsKey = 'notifications_task_assignments';
  static const String _taskDueTodayKey = 'notifications_task_due_today';
  static const String _taskDueTimeKey = 'notifications_task_due_time';
  static const String _shoppingKey = 'notifications_shopping';
  static const String _chatKey = 'notifications_chat';
  static const String _generalKey = 'notifications_general';
  static const String _darkModeKey = 'app_dark_mode';

  SharedPreferences? _prefs;

  bool _taskAssignments = true;
  bool _taskDueToday = true;
  TimeOfDay _taskDueTime = const TimeOfDay(hour: 7, minute: 0);
  bool _shopping = false;
  bool _chat = true;
  bool _general = true;
  bool _isDarkMode = true;

  bool get taskAssignments => _taskAssignments;
  bool get taskDueToday => _taskDueToday;
  TimeOfDay get taskDueTime => _taskDueTime;
  bool get shopping => _shopping;
  bool get chat => _chat;
  bool get general => _general;
  bool get isDarkMode => _isDarkMode;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    _taskAssignments = _prefs!.getBool(_taskAssignmentsKey) ?? true;
    _taskDueToday = _prefs!.getBool(_taskDueTodayKey) ?? true;

    final savedHour = _prefs!.getInt('${_taskDueTimeKey}_hour');
    final savedMinute = _prefs!.getInt('${_taskDueTimeKey}_minute');

    if (savedHour != null && savedMinute != null) {
      _taskDueTime = TimeOfDay(hour: savedHour, minute: savedMinute);
    }

    _shopping = _prefs!.getBool(_shoppingKey) ?? false;
    _chat = _prefs!.getBool(_chatKey) ?? true;
    _general = _prefs!.getBool(_generalKey) ?? true;
    _isDarkMode = _prefs!.getBool(_darkModeKey) ?? true;

    notifyListeners();
  }

  Future<void> setTaskAssignments(bool value) async {
    await _ensureInitialized();

    _taskAssignments = value;
    notifyListeners();

    await _prefs!.setBool(_taskAssignmentsKey, value);
  }

  Future<void> setTaskDueToday(bool value) async {
    await _ensureInitialized();

    _taskDueToday = value;
    notifyListeners();

    await _prefs!.setBool(_taskDueTodayKey, value);
  }

  Future<void> setTaskDueTime(TimeOfDay time) async {
    await _ensureInitialized();

    _taskDueTime = time;
    notifyListeners();

    await _prefs!.setInt('${_taskDueTimeKey}_hour', time.hour);
    await _prefs!.setInt('${_taskDueTimeKey}_minute', time.minute);
  }

  Future<void> setShopping(bool value) async {
    await _ensureInitialized();

    _shopping = value;
    notifyListeners();

    await _prefs!.setBool(_shoppingKey, value);
  }

  Future<void> setChat(bool value) async {
    await _ensureInitialized();

    _chat = value;
    notifyListeners();

    await _prefs!.setBool(_chatKey, value);
  }

  Future<void> setGeneral(bool value) async {
    await _ensureInitialized();

    _general = value;
    notifyListeners();

    await _prefs!.setBool(_generalKey, value);
  }

  Future<void> setIsDarkMode(bool value) async {
    await _ensureInitialized();

    _isDarkMode = value;
    notifyListeners();

    await _prefs!.setBool(_darkModeKey, value);
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}
