import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/onboarding_page.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';

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

    // Animasyon kontrolcüsünü başlatıyoruz
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // Animasyon süresi
      vsync: this,
    );

    // Büyüme (scale) animasyonu
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Yatay kayma animasyonu
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Animasyonu başlatıyoruz
    _controller.forward();

    // Belirli bir süre sonra WelcomeScreen'e geçiş
    Timer(const Duration(seconds: 3), () async {
      // 1) Onboarding daha önce tamamlanmış mı?
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;

      // 2) Gideceğin sayfayı seç
      Widget target;

      target = done ? AuthCheckScreen() : OnboardingScreen();

      if (!mounted) return;

      // 3) Animasyonlu yönlendirme (senin slide + fade'in)
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide: sağdan sola
            final slideAnimation = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOut)).animate(animation);

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeIn),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Animasyon kontrolcüsünü temizliyoruz
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
            tag: 'appLogo', // Animasyonun çalışacağı widget
            child: Image.asset(
              'assets/logo2.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
