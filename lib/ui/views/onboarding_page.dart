import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';

void main() => runApp(
  DevicePreview(
    enabled: !kReleaseMode,
    builder: (context) => MyApp(), // Wrap your app
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  bool isLastPage = false;
  int currentPageIndex = 0;


  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery
        .sizeOf(context)
        .width;
    var screenHeight = MediaQuery
        .sizeOf(context)
        .height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        child: SafeArea(
          child: Stack(
            children: [
              PageView(
                physics: BouncingScrollPhysics(),
                controller: controller,
                onPageChanged: (index) {
                  setState(() {
                    currentPageIndex = index; // Mevcut sayfa indexini güncelle
                    isLastPage = index == 2;
                  });
                },
                children: [
                  buildPage(
                    'En Uygun Sahayı Hemen Bul!',
                    'Konum, fiyat veya müsait tarihlere göre akıllı filtreler uygulayın; gerçek kullanıcı puanları ve samimi yorumlarla sahaların kalitesini karşılaştırın.',
                    'assets/onboarding1.png',
                    screenWidth,
                    screenHeight,
                  ),
                  buildPage(
                    'Takvimden Tarihi Seç, Yerini Ayır!',
                    'Müsait saatleri gör, tarih–saat seç, anında rezerve et. Dilersen abonelik başlat, her hafta aynı gün/saat garantili.',
                    'assets/onboarding2.png',
                    screenWidth,
                    screenHeight,
                  ),
                  buildPage(
                    'Bildirimsiz Kalma, Maçlardan Haberdar Ol!',
                    'Rezervasyon onaylandığında, iptal edildiğinde veya değiştiğinde anında bildirim al. Açmayı unutma!',
                    'assets/onboarding3.png',
                    screenWidth,
                    screenHeight,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: isLastPage
                    ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        _completeOnboarding();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation,
                                secondaryAnimation) => WelcomeScreen(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              // Slide animasyonu: sağdan sola
                              final slideTween = Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeOut));

                              final slideAnimation = animation.drive(
                                  slideTween);

                              // Fade animasyonu
                              final fadeAnimation = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeIn,
                              );

                              return SlideTransition(
                                position: slideAnimation,
                                child: FadeTransition(
                                  opacity: fadeAnimation,
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(
                                milliseconds: 400),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.2),
                        backgroundColor: Colors
                            .transparent, // Renk aşağıdaki boxDecoration’dan geliyor
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF10B981), // yeşilimsi
                              Color(0xFF22D3EE), // açık mavi
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Başla',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    : Row(
                  children: [
                    Spacer(flex: 1),
                    Visibility(
                      visible: currentPageIndex > 0,
                      maintainSize: true,
                      // Bu parametreyi ekleyin
                      maintainAnimation: true,
                      // Animasyonu korur
                      maintainState: true,

                      child: TextButton(
                        onPressed: () {
                          controller.previousPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(
                          "Geri",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    Spacer(flex: 4),

                    SmoothPageIndicator(
                      controller: controller,
                      count: 3,
                      effect: ExpandingDotsEffect(
                        dotHeight: 12,
                        dotWidth: 12,
                        activeDotColor: Colors.green,
                        dotColor: Colors.grey.withOpacity(0.3),

                        // Shadow parametreleri
                        //paintStyle: PaintingStyle.fill,
                        //  strokeWidth: 1.5,
                      ),
                    ),
                    Spacer(flex: 4),

                    TextButton(
                      onPressed: () {
                        controller.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text(
                        "İleri",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    Spacer(flex: 1),
                  ],
                ),
              ),

              Visibility(
                visible: currentPageIndex == 0,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    children: [
                      Spacer(flex: 14),
                      TextButton(
                        onPressed: () {
                          controller.jumpToPage(2);
                        },
                        child: Text(
                          "Atla",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPage(String title,
      String subtitle,
      String image,
      double screenWidth,
      double screenHeight,) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // Görsel
          Image.asset(
            image,
            height: screenHeight * 0.4,

          ),

          const SizedBox(height: 40),

          // Başlık
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 40),

          // Açıklama
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }
}


