import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wg_data.dart';
import 'home_page.dart';
import 'notifications/notification_preferences.dart';
import 'notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xcpbvuzazluqfgrvkgwp.supabase.co',
    publishableKey: 'sb_publishable_u6ytLk4KbPdOulUADY3Fag_qUPfpYYf',
  );

  try {
    await WGData.initialize();
  } catch (e, stackTrace) {
    debugPrint('WGData initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  final notificationPreferences = NotificationPreferences();
  await notificationPreferences.initialize();

  await NotificationService.instance.syncTaskNotifications(
    WGData.tasks,
    notificationPreferences,
  );

  runApp(
    ChangeNotifierProvider.value(
      value: notificationPreferences,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WG',
      theme: ThemeData(
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
      home: const HomePage(),
    );
  }
}
