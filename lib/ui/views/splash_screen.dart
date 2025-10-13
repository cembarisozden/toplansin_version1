import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔽 EKLEDİK: RC + servis + diyalog
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:toplansin/core/update/update_service.dart';
import 'package:toplansin/core/update/update_dialog.dart';

import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/onboarding_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Başlat
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    // En az 3 sn splash kalsın
    final splashMin = Future.delayed(const Duration(seconds: 3));
    final info = await PackageInfo.fromPlatform();
    print('BUILD NUMBER = ${info.buildNumber}');


    // Güncelleme kontrolü (diyalog gerekiyorsa gösterecek)
     await _checkAndMaybeShowUpdate();

    // 3 sn’yi garanti et
    await splashMin;

    if (!mounted) return;

    // Onboarding bitti mi?
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    final Widget target = done ? AuthCheckScreen() : OnboardingScreen();

    // Geçiş
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOut)).animate(animation);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// RC'den min/latest değerlerini alır, gerekiyorsa update diyalogunu açar.
  Future<void> _checkAndMaybeShowUpdate() async {
    try {
      // main.dart’ta initialize ettiyseniz de try/catch ile güvenli.
      await Firebase.initializeApp();
    } catch (_) {}

    final decision = await UpdateService.evaluate();
    if (!mounted || decision.kind == UpdateKind.none) return;

    final rc = FirebaseRemoteConfig.instance;
    final mandatory = decision.kind == UpdateKind.mandatory;
    final title = mandatory
        ? rc.getString('force_title_tr')
        : rc.getString('soft_title_tr');
    final msg = decision.message ?? '';

    await showUpdateDialog(
      context: context,
      mandatory: mandatory,
      title: title.isEmpty
          ? (mandatory ? 'Güncelleme Gerekli' : 'Yeni Sürüm Mevcut')
          : title,
      message: msg,
      ctaUpdate: rc.getString('cta_update_tr').isEmpty
          ? 'Güncelle'
          : rc.getString('cta_update_tr'),
      ctaLater: rc.getString('cta_later_tr').isEmpty
          ? 'Daha Sonra'
          : rc.getString('cta_later_tr'),
      onUpdate: () => UpdateService.openStore(decision.storeUrl),
      onLater: mandatory
          ? null
          : () => UpdateService.snoozeSoft(
        (decision.snoozeHours <= 0) ? 24 : decision.snoozeHours,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Hero(
            tag: 'appLogo',
            child: Image.asset('assets/logo2.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
