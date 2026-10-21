import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
  'smart_customer_alerts',
  'Notifikasi Smart Customer',
  description: 'Notifikasi dari aplikasi Smart Customer.',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  static Future<void> initialize() async {
    // Notifikasi hanya diaktifkan pada Android.
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      debugPrint(
        'Notifikasi hanya diaktifkan pada Android.',
      );
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
    );

    await localNotifications.initialize(
      settings: initializationSettings,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(notificationChannel);

    final settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Status izin notifikasi: '
      '${settings.authorizationStatus}',
    );

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        final notification = message.notification;

        if (notification == null) return;

        await localNotifications.show(
          id: notification.hashCode,
          title: notification.title ?? 'Smart Customer',
          body: notification.body ?? '',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'smart_customer_alerts',
              'Notifikasi Smart Customer',
              channelDescription:
                  'Notifikasi dari aplikasi Smart Customer.',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      },
    );

    final token = await FirebaseMessaging.instance.getToken();

    if (kDebugMode && token != null) {
      debugPrint('FCM TOKEN: $token');
    }
  }
}