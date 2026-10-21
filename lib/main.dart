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
      // Do not prevent the rest of Smart Customer from starting if notifications
      // cannot initialize (e.g. permission or FCM configuration issue).
    }
  }

  runApp(const SmartCustomerApp());
}

class SmartCustomerApp extends StatelessWidget {
  const SmartCustomerApp({super.key});

  Widget _protected(Widget child) => AuthGate(child: child);

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
