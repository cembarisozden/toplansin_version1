import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:toplansin/core/providers/FavoritesProvider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';
import 'package:toplansin/firebase_options.dart';
import 'package:toplansin/services/connectivity_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/services/user_notification_service.dart';
import 'package:toplansin/core/providers/OwnerNotificationProvider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/banner/pro_connectivity_banner.dart';
import 'package:toplansin/ui/views/splash_screen.dart';
import 'package:toplansin/core/providers/PhoneVerificationProvider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  UserNotificationService.showLocal(message);
}

Future<bool> _hasNetwork() async =>
    (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

/* ─────────────────────────────────────────────────────────────── */

bool _onlineServicesReady = false;
Future<void> _initOnlineServices() async {
  if (_onlineServicesReady) return;
  _onlineServicesReady = true;

  await UserNotificationService.init();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

Future<void> _updateServerTime() async {
  const fn = 'updateServerTime';
  try {
    await FirebaseFunctions.instance
        .httpsCallable(fn)
        .call()
        .timeout(const Duration(seconds: 4));
    debugPrint('✅ $fn başarılı');
  } catch (e, st) {
    debugPrint('⚠️ $fn başarısız: $e');
    FirebaseCrashlytics.instance
        .recordError(e, st, reason: '$fn hata / offline');
  }
}

/* ─────────────────────────────────────────────────────────────── */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase + offline cache
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings =
  const Settings(persistenceEnabled: true);

  // 2) App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback,
  );

  // 3) Lokal formatter ve portre kilidi
  await initializeDateFormatting('tr');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 4) Crashlytics hata handler
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // 5) UI hemen ayağa kalksın!
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OwnerNotificationProvider()),
          ChangeNotifierProvider(create: (_) => UserNotificationProvider()),
          ChangeNotifierProvider(create: (_) => PhoneVerificationProvider()),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );

  // ——————————————————————————
  // 6) Artık app açıldı, arkada devam edelim
  final onlineAtLaunch = await _hasNetwork();
  if (onlineAtLaunch) {
    await _initOnlineServices();      // FCM, local notifications vs.
    await _updateServerTime();        // sunucu saati
  } else {
    FirebaseFirestore.instance.disableNetwork(); // Firestore çökmesin
  }

  // 7) TimeService init’i offline’ı yutacak şekilde
  try {
    await TimeService.init();
  } catch (e) {
    debugPrint('⚠️ TimeService.init hata (offline?): $e');
  }

  // 8) Ağa bağlanınca otomatik tekrar dene
  Connectivity().onConnectivityChanged.listen((result) async {
    if (result != ConnectivityResult.none) {
      await _initOnlineServices();
      await _updateServerTime();
    }
  });
}


/* ─────────────────────────────────────────────────────────────── */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toplansın',
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
        fontFamily: GoogleFonts.manrope().fontFamily,
        textTheme:  AppTextStyles.textTheme,
      ),
      // ➊ Lokalizasyon delegeleri
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ➋ Desteklenen diller
      supportedLocales: const [
        Locale('en', ''), // İngilizce (fallback)
        Locale('tr', ''), // Türkçe
      ],
      // ➌ Uygulama dili (opsiyonel; cihaz ayarını kullanmak istiyorsanız kaldırın)
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        final previewed = DevicePreview.appBuilder(context, child);
        return Stack(
          children: [
            previewed,
            StreamBuilder<bool>(
              stream: ConnectivityService.instance.connectivity$,
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? true;
                return ProConnectivityBanner(offline: !isConnected);
              },
            ),
          ],
        );
      },

      home: const SplashScreen(),
    );
  }
}
