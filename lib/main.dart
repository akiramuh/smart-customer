import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/analytics_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/history_page.dart';
import 'screens/main_navigation.dart';
import 'screens/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SmartCustomerApp());q
}

class SmartCustomerApp extends StatelessWidget {
  const SmartCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Customer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      ),
      routes: {
        '/': (_) => const MainNavigation(),
        '/dashboard': (_) => const DashboardPage(),
        '/analytics': (_) => const AnalyticsPage(),
        '/history': (_) => const HistoryPage(),
        '/settings': (_) => const SettingsPage(),
      },
      initialRoute: '/',
    );
  }
}
