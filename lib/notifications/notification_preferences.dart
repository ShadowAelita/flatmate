import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardCard {
  final String id;
  final String name;
  bool isVisible;

  DashboardCard({required this.id, required this.name, this.isVisible = true});

  DashboardCard copyWith({bool? isVisible}) {
    return DashboardCard(id: id, name: name, isVisible: isVisible ?? this.isVisible);
  }
}

class NotificationPreferences extends ChangeNotifier {
  static const String _taskAssignmentsKey = 'notifications_task_assignments';
  static const String _taskDueTodayKey = 'notifications_task_due_today';
  static const String _taskDueTimeKey = 'notifications_task_due_time';
  static const String _shoppingKey = 'notifications_shopping';
  static const String _chatKey = 'notifications_chat';
  static const String _generalKey = 'notifications_general';
  static const String _darkModeKey = 'app_dark_mode';
  static const String _dashboardCardsKey = 'dashboard_cards';
  static const String _inventoryAutoCreateShoppingKey = 'inventory_auto_create_shopping';

  SharedPreferences? _prefs;

  bool _taskAssignments = true;
  bool _taskDueToday = true;
  TimeOfDay _taskDueTime = const TimeOfDay(hour: 7, minute: 0);
  bool _shopping = false;
  bool _chat = true;
  bool _general = true;
  bool _isDarkMode = true;
  List<DashboardCard> _dashboardCards = [];

  static const List<String> _defaultCardOrder = [
    'shopping',
    'inventory',
    'tasks',
    'chat',
    'balance',
    'members',
  ];

  static const Map<String, String> _cardNames = {
    'shopping': 'Einkaufen',
    'inventory': 'Inventar',
    'tasks': 'Aufgaben',
    'chat': 'Chat',
    'balance': 'WG-Kasse',
    'members': 'Unsere WG',
  };

  bool get taskAssignments => _taskAssignments;
  bool get taskDueToday => _taskDueToday;
  TimeOfDay get taskDueTime => _taskDueTime;
  bool get shopping => _shopping;
  bool get chat => _chat;
  bool get general => _general;
  bool get isDarkMode => _isDarkMode;
  List<DashboardCard> get dashboardCards => List.unmodifiable(_dashboardCards);
  bool get inventoryAutoCreateShopping => _inventoryAutoCreateShopping;
  bool _inventoryAutoCreateShopping = true;

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

    _inventoryAutoCreateShopping = _prefs!.getBool(_inventoryAutoCreateShoppingKey) ?? true;

    await _loadDashboardCards();

    notifyListeners();
  }

  Future<void> _loadDashboardCards() async {
    final savedCardsJson = _prefs!.getString(_dashboardCardsKey);

    if (savedCardsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedCardsJson);
        _dashboardCards = decoded.map((cardJson) {
          return DashboardCard(
            id: cardJson['id'] as String,
            name: _cardNames[cardJson['id']] ?? cardJson['id'],
            isVisible: cardJson['isVisible'] as bool? ?? true,
          );
        }).toList();

        final savedIds = _dashboardCards.map((c) => c.id).toSet();
        for (final defaultId in _defaultCardOrder) {
          if (!savedIds.contains(defaultId)) {
            _dashboardCards.add(DashboardCard(
              id: defaultId,
              name: _cardNames[defaultId] ?? defaultId,
              isVisible: true,
            ));
          }
        }
      } catch (_) {
        _initializeDefaultDashboardCards();
      }
    } else {
      _initializeDefaultDashboardCards();
    }
  }

  void _initializeDefaultDashboardCards() {
    _dashboardCards = _defaultCardOrder.map((id) {
      return DashboardCard(
        id: id,
        name: _cardNames[id] ?? id,
        isVisible: true,
      );
    }).toList();
  }

  Future<void> _saveDashboardCards() async {
    final cardsJson = jsonEncode(_dashboardCards.map((card) {
      return {'id': card.id, 'isVisible': card.isVisible};
    }).toList());
    await _prefs!.setString(_dashboardCardsKey, cardsJson);
  }

  Future<void> toggleDashboardCard(String cardId) async {
    await _ensureInitialized();

    final index = _dashboardCards.indexWhere((c) => c.id == cardId);
    if (index != -1) {
      _dashboardCards[index].isVisible = !_dashboardCards[index].isVisible;
      notifyListeners();
      await _saveDashboardCards();
    }
  }

  Future<void> reorderDashboardCards(int oldIndex, int newIndex) async {
    await _ensureInitialized();

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final card = _dashboardCards.removeAt(oldIndex);
    _dashboardCards.insert(newIndex, card);

    notifyListeners();
    await _saveDashboardCards();
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

  Future<void> setInventoryAutoCreateShopping(bool value) async {
    await _ensureInitialized();

    _inventoryAutoCreateShopping = value;
    notifyListeners();

    await _prefs!.setBool(_inventoryAutoCreateShoppingKey, value);
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}
