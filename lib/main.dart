import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/FavoritesProvider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';

import 'package:toplansin/firebase_options.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/services/user_notification_service.dart';
import 'package:toplansin/core/providers/OwnerNotificationProvider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/ui/views/splash_screen.dart';
import 'package:toplansin/core/providers/PhoneVerificationProvider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  UserNotificationService.showLocal(message); // senin mevcut servis
}

void main() async {

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);


    await initializeDateFormatting('tr');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // 🔴 Flutter framework hatalarını Crashlytics'e gönder
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // 🔔 Bildirim altyapısını başlat
    await UserNotificationService.init();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 🕒 Zaman senkronizasyonu + Crashlytics UID
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        FirebaseCrashlytics.instance
            .setUserIdentifier(user.uid); // ✍️ UID logla
      }

      await FirebaseFunctions.instance.httpsCallable('updateServerTime').call();
      print("✅ server_time güncellendi");
    } catch (e, stack) {
      print("⚠️ server_time güncellenemedi: $e");
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: "Server time güncelleme hatası");
    }

    await TimeService.init();

    runApp(
      DevicePreview(
        enabled: !kReleaseMode, // Sadece debug modda çalışır
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<OwnerNotificationProvider>(
              create: (_) => OwnerNotificationProvider(),
            ),
            ChangeNotifierProvider<UserNotificationProvider>(
              create: (_) => UserNotificationProvider(),
            ),
            ChangeNotifierProvider<PhoneVerificationProvider>(
              create: (_) => PhoneVerificationProvider(),
            ),
            ChangeNotifierProvider<HomeProvider>(
              create: (_) => HomeProvider(),
            ),
            ChangeNotifierProvider<FavoritesProvider>(
              create: (_) => FavoritesProvider(),
            ),
          ],
          child: const MyApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    // 🔥 Async context dışı hatalar
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toplansın',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context),
      home: const SplashScreen(),
    );
  }
}
