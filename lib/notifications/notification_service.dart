import 'dart:io';

import 'package:flutter/material.dart';
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
      body: 'Benachrichtigungen funktionieren.',
      notificationDetails: details,
    );
  }

  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_chat',
      'Chat',
      channelDescription: 'Benachrichtigungen über neue Chat-Nachrichten',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 2000,
      title: senderName,
      body: messageText,
      notificationDetails: details,
    );
  }

  Future<void> showShoppingNotification({
    required String personName,
    required String itemName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_shopping',
      'Einkaufen',
      channelDescription: 'Benachrichtigungen über die Einkaufsliste',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 3000,
      title: '$personName hat $itemName zur Einkaufsliste hinzugefügt',
      body: itemName,
      notificationDetails: details,
    );
  }

  Future<void> showMemberJoinedNotification({
    required String memberName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_general',
      'Flatmate',
      channelDescription: 'Allgemeine Flatmate-Benachrichtigungen',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 4000,
      title: '$memberName ist der WG beigetreten',
      body: '$memberName hat sich der Wohngemeinschaft angeschlossen',
      notificationDetails: details,
    );
  }

  Future<void> showMemberLeftNotification({
    required String memberName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_general',
      'Flatmate',
      channelDescription: 'Allgemeine Flatmate-Benachrichtigungen',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 5000,
      title: '$memberName hat die WG verlassen',
      body: '$memberName hat die Wohngemeinschaft verlassen',
      notificationDetails: details,
    );
  }

  Future<void> showTaskAssignedNotification({
    required String assigneeName,
    required String taskName,
    String? assignerName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_tasks',
      'Aufgaben',
      channelDescription: 'Benachrichtigungen über Aufgaben',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = assignerName != null
        ? '$assignerName hat dir eine Aufgabe zugewiesen'
        : 'Dir wurde eine Aufgabe zugewiesen';

    await _plugin.show(
      id: 6000,
      title: title,
      body: taskName,
      notificationDetails: details,
    );
  }

  Future<void> showTaskDueTodayNotification({
    required String taskId,
    required String taskName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_tasks',
      'Aufgaben',
      channelDescription: 'Benachrichtigungen über Aufgaben',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: _notificationIdForTask(taskId),
      title: 'Aufgabe fällig heute',
      body: taskName,
      notificationDetails: details,
      payload: 'task:$taskId',
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

     final scheduledTime = _notificationTimeForDueDate(
       dueDate,
       preferences.taskDueTime,
     );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'flatmate_tasks',
      'Aufgaben',
      channelDescription: 'Benachrichtigungen über Aufgaben',
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
      title: 'Aufgabe fällig heute',
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

   Future<void> triggerDueTodayNotifications({
     required List<Map<String, dynamic>> tasks,
     required String? currentMemberId,
     required NotificationPreferences preferences,
   }) async {
     if (!_initialized) {
       await initialize();
     }

     if (!preferences.taskDueToday) return;

     final today = DateTime.now();
     final todayDate = DateTime(today.year, today.month, today.day);

     for (final task in tasks) {
       final completed = task['completed'] == true;

       if (completed) continue;

       final dueDateValue = task['dueDate']?.toString();

       if (dueDateValue == null) continue;

       final dueDate = DateTime.tryParse(dueDateValue);

       if (dueDate == null) continue;

       final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

       if (dueDateOnly != todayDate) continue;

       final assignedTo = task['assignedTo']?.toString();

       if (assignedTo != null &&
           assignedTo != currentMemberId &&
           assignedTo != 'nobody') {
         continue;
       }

       final taskId = task['id']?.toString();

       if (taskId == null) continue;

       await showTaskDueTodayNotification(
         taskId: taskId,
         taskName: task['name']?.toString() ?? 'Aufgabe',
       );
     }
   }

   tz.TZDateTime _notificationTimeForDueDate(
     DateTime dueDate,
     TimeOfDay timeOfDay,
   ) {
     final localDate = tz.TZDateTime(
       tz.local,
       dueDate.year,
       dueDate.month,
       dueDate.day,
     );

     return tz.TZDateTime(
       tz.local,
       localDate.year,
       localDate.month,
       localDate.day,
       timeOfDay.hour,
       timeOfDay.minute,
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
