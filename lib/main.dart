import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:toplansin/firebase_options.dart';
import 'package:toplansin/services/time_service.dart';

import 'package:toplansin/ui/views/notification_provider.dart';
import 'package:toplansin/ui/views/splash_screen.dart';
import 'package:toplansin/services/notification_service.dart';   // <-- yeni servis

/// Arka planda gelen FCM mesajlarını yakalayan zorunlu top-level fonksiyon
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Bildirimi local olarak göster (NotificationService içinde tanımlı)
  NotificationService.showLocal(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bildirim servisini hazırla (izinler, token kaydı, dinleyiciler)
  await NotificationService.init();


  try {
    await FirebaseFunctions.instance.httpsCallable('updateServerTime').call();
    print("✅ server_time güncellendi");
  } catch (e) {
    print("⚠️ server_time güncellenemedi: $e");
  }
  await TimeService.init();

  // Arka plan handler’ı kaydet
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Tarih-saat için Türkçe yerelleştirme
  await initializeDateFormatting('tr');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toplansın',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
