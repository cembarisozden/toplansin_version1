import 'dart:async';
import 'package:flutter/material.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon kontrolcüsünü başlatıyoruz
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000), // Animasyon süresi
      vsync: this,
    );

    // Büyüme (scale) animasyonu
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Geçiş animasyonu: Fade + Slide
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
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
      backgroundColor: Colors.green[500],
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Hero(
            tag: 'appLogo', // Animasyonun çalışacağı widget
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
