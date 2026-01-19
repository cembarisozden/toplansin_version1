import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class UserNotificationService {
  /* ---------- Singleton ---------- */
  UserNotificationService._();
  static final UserNotificationService I = UserNotificationService._();

  /* ---------- Alanlar ---------- */
  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Toplansın için kritik bildirim kanalı',
    importance: Importance.max,
  );

  /* ---------- Init (main() içinde bir kez çağır) ---------- */
  static Future<void> init() async {
    // ✅ Firebase zaten main.dart'ta initialize edildi, tekrar gerek yok

    // 1️⃣ İzin iste (Android 13+, iOS)
    final settings = await I._fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2️⃣ iOS ön planda bildirim göster
    await I._fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3️⃣ Local notification plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await I._local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 4️⃣ Android kanal
    await I._local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 5️⃣ İlk token'i kaydet
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await I.saveTokenToFirestore();
    }

    // 6️⃣ Dinleyiciler
    FirebaseMessaging.onMessage.listen(_onMessageForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    // ✅ Background handler main.dart'ta tanımlı

    // 7️⃣ Token yenileme
    FirebaseMessaging.instance.onTokenRefresh.listen(I._updateToken);
  }

  /* ---------- Token kaydet ---------- */
  Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return;

    String? token;

    if (Platform.isIOS) {
      // iOS: getToken() SIMÜLATÖRDE exception fırlatabilir
      try {
        token = await _fm.getToken();
      } catch (_) {
        // APNs hazır değil -> simülatör / erken aşama
      }

      // Hâlâ null ise APNS token'ı deneyelim (gerçek cihazda gelebilir)
      token ??= await _fm.getAPNSToken();
      if (token == null) return; // Token sonra onTokenRefresh ile gelecek
    } else {
      // Android tarafı
      token = await _fm.getToken();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> _updateToken(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': newToken});
    }
  }

  /* ---------- Mesaj callback'leri ---------- */
  static void _onMessageForeground(RemoteMessage m) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        m.notification != null) {
      showLocal(m);
    }
  }

  static void _onNotificationTap(NotificationResponse d) {
    // TODO: Bildirime tıklandığında yönlendirme yap
  }

  static void _onMessageOpenedApp(RemoteMessage m) {
    // TODO: Bildirime tıklayıp uygulamayı açınca yapılacaklar
  }

  /* ---------- Local bildirim ---------- */
  static Future<void> showLocal(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await I._local.show(
      n.hashCode,
      n.title,
      n.body,
      details,
      payload: m.data['reservationId'],
    );
  }
}
