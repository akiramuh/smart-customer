import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'screens/analytics_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/history_page.dart';
import 'screens/main_navigation.dart';
import 'screens/settings_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM and local notifications are initialized only on Android.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    try {
      await NotificationService.initialize();
    } catch (error, stackTrace) {
      debugPrint('Inisialisasi notifikasi Android gagal: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(const SmartCustomerApp());
}

class SmartCustomerApp extends StatelessWidget {
  const SmartCustomerApp({super.key});

  Widget _protected(Widget child) => AuthGate(child: child);

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF175CD3);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Customer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7FB),
          foregroundColor: Color(0xFF172B4D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF172B4D),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE7ECF3)),
          ),
        ),
        dividerColor: const Color(0xFFE7ECF3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),
      routes: {
        '/': (_) => _protected(const MainNavigation()),
        '/dashboard': (_) => _protected(const DashboardPage()),
        '/analytics': (_) => _protected(const AnalyticsPage()),
        '/history': (_) => _protected(const HistoryPage()),
        '/settings': (_) => _protected(const SettingsPage()),
      },
      initialRoute: '/',
    );
  }
}
