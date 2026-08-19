import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_preferences.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initializationSettings);

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_general',
      'Flatmate',
      channelDescription: 'General Flatmate notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 1000,
      title: 'Flatmate',
      body: 'Notifications are working.',
      notificationDetails: details,
    );
  }

  Future<void> scheduleTaskDueToday({
    required String taskId,
    required String taskName,
    required DateTime dueDate,
    required NotificationPreferences preferences,
  }) async {
    if (!preferences.taskDueToday) {
      await cancelTaskNotification(taskId);
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    final scheduledTime = _notificationTimeForDueDate(dueDate);

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_tasks',
      'Tasks',
      channelDescription: 'Notifications about Flatmate tasks',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: _notificationIdForTask(taskId),
      title: 'Task due today',
      body: taskName,
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'task:$taskId',
    );
  }

  Future<void> syncTaskNotifications(
    List<Map<String, dynamic>> tasks,
    NotificationPreferences preferences,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    for (final task in tasks) {
      final taskId = task['id']?.toString();

      if (taskId == null) {
        continue;
      }

      final completed = task['completed'] == true;
      final dueDateValue = task['dueDate'];

      if (completed || dueDateValue == null) {
        await cancelTaskNotification(taskId);
        continue;
      }

      final dueDate = DateTime.tryParse(dueDateValue.toString());

      if (dueDate == null) {
        await cancelTaskNotification(taskId);
        continue;
      }

      await scheduleTaskDueToday(
        taskId: taskId,
        taskName: task['name']?.toString() ?? 'Aufgabe',
        dueDate: dueDate,
        preferences: preferences,
      );
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    await _plugin.cancel(id: _notificationIdForTask(taskId));
  }

  Future<void> cancelAllTaskNotifications() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _notificationTimeForDueDate(DateTime dueDate) {
    final localDate = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    // For now, notify at 08:00 on the due date.
    return tz.TZDateTime(
      tz.local,
      localDate.year,
      localDate.month,
      localDate.day,
      8,
    );
  }

  int _notificationIdForTask(String taskId) {
    var hash = 0;

    for (final codeUnit in taskId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash;
  }

  @visibleForTesting
  bool get isInitialized => _initialized;
}
