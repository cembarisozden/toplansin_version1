// main.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toplansin/core/di/injector.dart';

import 'package:toplansin/core/providers/FavoritesProvider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';
import 'package:toplansin/core/providers/acces_code_provider.dart';
import 'package:toplansin/core/providers/bottomNavProvider.dart';
import 'package:toplansin/core/providers/owner_providers/StatsProvider.dart';
import 'package:toplansin/core/providers/owner_providers/owner_activate_code_with_users_provider.dart';
import 'package:toplansin/firebase_options.dart';
import 'package:toplansin/keyboardKit.dart';
import 'package:toplansin/services/connectivity_service.dart';
import 'package:toplansin/services/firebase_functions_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/services/user_notification_service.dart';
import 'package:toplansin/core/providers/owner_providers/OwnerNotificationProvider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/banner/pro_connectivity_banner.dart';
import 'package:toplansin/ui/views/splash_screen.dart';
import 'package:toplansin/core/providers/PhoneVerificationProvider.dart';
import 'package:timezone/data/latest.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }

    // 🔧 Background izolat için App Check (try-catch ile güvenli)
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (_) {
      // App Check başarısız olsa bile devam et
    }

    await UserNotificationService.showLocal(message);
  } catch (e, st) {
    await FirebaseCrashlytics.instance
        .recordError(e, st, reason: 'FCM background handler', fatal: false);
  }
}

Future<bool> _hasNetwork() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  } catch (e) {
    debugPrint('⚠️ Connectivity check failed: $e');
    return true; // Hata durumunda online varsay, sonra düzeltilir
  }
}

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
    await functions
        .httpsCallable(fn)
        .call()
        .timeout(const Duration(seconds: 60));
    debugPrint('✅ $fn başarılı');
  } catch (e, st) {
    debugPrint('⚠️ $fn başarısız: $e');
    FirebaseCrashlytics.instance
        .recordError(e, st, reason: '$fn hata / offline');
  }
}

/* ─────────────────────────────────────────────────────────────── */

Future<void> main() async {
  // ✅ KRİTİK: Tüm init ve runApp aynı zone'da olmalı
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Timezone init
  tz.initializeTimeZones();

  // ✅ Firebase init (native tarafta zaten configure edildiyse tekrar yapma)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // ✅ App Check - try-catch içinde (iOS keychain sorunları için)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint('⚠️ App Check activation failed: $e');
  }

  // ✅ Crashlytics setup - runZonedGuarded KULLANMADAN
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  // Flutter framework hataları
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Async/Platform hataları
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Isolate hataları
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final List<dynamic> errorAndStacktrace = pair;
    final error = errorAndStacktrace.first;
    final stack = StackTrace.fromString(errorAndStacktrace.last as String);
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }).sendPort);

  // ✅ Lokal formatter ve portre kilidi
  await initializeDateFormatting('tr');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 🔹 Edge-to-Edge Mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ✅ DI setup
  await setup();

  // ✅ Uygulama - aynı zone'da
  runApp(
    DevicePreview(
      enabled: false,
      builder: (previewContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OwnerNotificationProvider()),
            ChangeNotifierProvider(create: (_) => UserNotificationProvider()),
            ChangeNotifierProvider(create: (_) => PhoneVerificationProvider()),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => StatsProvider()),
            ChangeNotifierProvider(create: (_) => BottomNavProvider()),
            ChangeNotifierProvider(create: (_) => AccessCodeProvider()),
            ChangeNotifierProvider(
                create: (_) => OwnerActivateCodeWithUsersProvider()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(411.42857142857144, 914.2857142857143),
            useInheritedMediaQuery: true,
            minTextAdapt: true,
            builder: (context, child) => const MyApp(),
            child: const SizedBox.shrink(),
          ),
        );
      },
    ),
  );

  // ——————————————————————————
  // App açıldıktan sonra arka işler (async, runApp'tan sonra)
  _initBackgroundTasks();
}

/// Arka plan görevlerini başlat (runApp'tan sonra çağrılır)
Future<void> _initBackgroundTasks() async {
  final onlineAtLaunch = await _hasNetwork();
  if (onlineAtLaunch) {
    await _initOnlineServices();
    await _updateServerTime();
  } else {
    FirebaseFirestore.instance.disableNetwork();
  }

  // TimeService init (offline toleranslı)
  try {
    await TimeService.init();
  } catch (e) {
    debugPrint('⚠️ TimeService.init hata (offline?): $e');
  }

  // Ağa bağlanınca otomatik tekrar dene
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
      navigatorObservers: [KeyboardUnfocusObserver()],
      builder: (context, child) {
        final previewed = DevicePreview.appBuilder(context, child);
        return TapRegion(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
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
          ),
        );
      },
      title: 'Toplansın',
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily,
        textTheme: AppTextStyles.textTheme,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('tr', ''),
      ],
      locale: const Locale('tr', 'TR'),
      home: const SplashScreen(),
    );
  }
}
