import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

const String smartCustomerAlertTopic = 'smart_customer_alerts';

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
  smartCustomerAlertTopic,
  'Notifikasi Smart Customer',
  description: 'Notifikasi ketika minimarket mencapai ambang ramai.',
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
  static bool _initialized = false;

  static Future<void> initialize() async {
    // This app intentionally supports push notifications on Android only.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('Notifikasi hanya diaktifkan pada Android.');
      return;
    }

    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await localNotifications.initialize(
      settings: initializationSettings,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(notificationChannel);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Status izin notifikasi: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint(
        'Izin notifikasi belum diaktifkan; perangkat belum subscribe FCM topic.',
      );
      return;
    }

    // All authorized Android team devices subscribed to this topic will receive
    // crowd alerts from the Python Firebase Admin SDK.
    await FirebaseMessaging.instance.subscribeToTopic(smartCustomerAlertTopic);
    debugPrint('Berhasil subscribe FCM topic: $smartCustomerAlertTopic');

    // Android displays notification payloads automatically while app is in the
    // background. While foregrounded, show it as a local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      await localNotifications.show(
        id: notification.hashCode,
        title: notification.title ?? 'Smart Customer',
        body: notification.body ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            smartCustomerAlertTopic,
            'Notifikasi Smart Customer',
            channelDescription:
                'Notifikasi ketika minimarket mencapai ambang ramai.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    });

    _initialized = true;
  }
}
