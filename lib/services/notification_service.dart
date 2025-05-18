import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../firebase_options.dart';

/// Arka planda gelen mesajlar için *zorunlu* top‑level handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // Eğer mesajda notification alanı varsa
  // sistem zaten bildirimi gösterdiği için tekrar göstermeyelim.
  if (message.notification == null) {
    NotificationService.showLocal(message); // ← yalnızca data-only ise
  }
}


class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  static NotificationService get I => _instance;

  // ----- Dahili alanlar -----
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Toplansın uygulaması için kritik bildirim kanalı',
    importance: Importance.max,
  );

  /// Uygulama başlatıldığında *bir kez* çağır
  static Future<void> init() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // iOS & Android bildirim izinleri
    await I.messaging.requestPermission();

    // Local notification ayarları (Android için kanal, iOS için varsayılan)
    await I._local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.
    createNotificationChannel(I._androidChannel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await I._local.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Bildirime tıklayınca yapılacaklar
        });

    // Token Firestore'a yaz


    // Dinleyiciler
    FirebaseMessaging.onMessage.listen((message) {
      // Uygulama gerçekten ekrandayken (resumed) ve bildirimin
      // notification alanı varsa local göster.
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          message.notification != null) {
        NotificationService.showLocal(message);
      }
    });





    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      // Bildirime tıklayıp açtığında yapılacaklar
    });

    // Arkaplan handler'ı kaydet
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);


    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
        });
      }
    });
  }

  // ----- Token Kaydet -----
  Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      print("[TOKEN] Kullanıcı doğrulanmamış, token yazımı iptal edildi.");
      return;
    }
    final token = await messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  // ----- Local Notif Göster -----
  static Future<void> showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      I._androidChannel.id,
      I._androidChannel.name,
      channelDescription: I._androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();

    final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await I._local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['reservationId'],
    );
  }
}
