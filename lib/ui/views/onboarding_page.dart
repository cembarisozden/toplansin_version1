import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/login_page.dart';

class OnboardingPage extends StatelessWidget {
  OnboardingPage({Key? key}) : super(key: key);

  // IntroductionScreen’i kontrol etmek için:
  final _introKey = GlobalKey<IntroductionScreenState>();

  /* ─────────────── Helpers ─────────────── */
  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) =>  AuthCheckScreen()),
    );
  }

  Widget _buildImage(String fileName, {double width = 280}) =>
      Image.asset('assets/$fileName', width: width);

  /* ─────────────── UI ─────────────── */
  @override
  Widget build(BuildContext context) {
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,          // markayla uyumlu
      ),
      bodyTextStyle: TextStyle(
        fontSize: 18,
        color: AppColors.surface,
      ),
      bodyPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      imagePadding: EdgeInsets.only(top: 24),
      pageColor: AppColors.surface,
    );

    return IntroductionScreen(
      key: _introKey,
      globalBackgroundColor: AppColors.surface,
      pages: [
        PageViewModel(
          title: 'Kolayca Rezervasyon Yapın',
          body:
          'Tek dokunuşla halı saha rezervasyonunuzu oluşturun, takım arkadaşlarınıza davet gönderin.',
          image: _buildImage('onboarding1.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'Müsait Saatleri Anında Görün',
          body:
          'Seçtiğiniz saha için güncel müsait saatleri inceleyin, size en uygun zamanı seçin.',
          image: _buildImage('onboarding2.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'Abonelik ve Hatırlatıcılar',
          body:
          'Haftalık abonelikler oluşturun, otomatik bildirimlerle maçlarınızı kaçırmayın.',
          image: _buildImage('onboarding3.png'),
          decoration: pageDecoration,
        ),
      ],

      /* ─────────────── Kontroller ─────────────── */
      showSkipButton: true,
      skip: const Text('Atla', style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Başla', style: TextStyle(fontWeight: FontWeight.w600)),
      onSkip: () => _goToLogin(context),
      onDone: () => _goToLogin(context),

      /* ─────────────── Nokta Göstergeleri ─────────────── */
      dotsDecorator: DotsDecorator(
        size: const Size.square(10),
        activeSize: const Size(22, 10),
        spacing: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.grey.withOpacity(0.2),
        activeColor: AppColors.primary,
        activeShape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}
