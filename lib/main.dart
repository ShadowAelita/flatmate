import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications/notification_preferences.dart';
import 'notifications/notification_service.dart';
import 'register_page.dart';
import 'wg_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseFuture = Supabase.initialize(
    url: 'https://xcpbvuzazluqfgrvkgwp.supabase.co',
    publishableKey: 'sb_publishable_u6ytLk4KbPdOulUADY3Fag_qUPfpYYf',
  );

  final notificationPreferences = NotificationPreferences();
  final prefsFuture = notificationPreferences.initialize();

  await Future.wait([supabaseFuture, prefsFuture]);

  try {
    await WGData.initialize();
  } catch (e, stackTrace) {
    debugPrint('WGData initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  WGData.setNotificationPreferences(notificationPreferences);

  runApp(
    ChangeNotifierProvider.value(
      value: notificationPreferences,
      child: const MyApp(),
    ),
  );

  unawaited(
    NotificationService.instance.syncTaskNotifications(
      WGData.tasks,
      notificationPreferences,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<NotificationPreferences>().isDarkMode;

    return MaterialApp(
      title: 'WG',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      navigatorKey: WGData.navigatorKey,
      home: const GatePage(),
    );
  }
}
