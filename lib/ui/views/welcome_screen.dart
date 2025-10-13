import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toplansin/ui/user_views/explore_pitches_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/views/login_page.dart';
import 'package:toplansin/ui/views/sign_up_page.dart';



class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, String>> features = [
    {
      "title": "Hızlı Rezervasyon",
      "description": "Tek tıkla halı saha rezervasyonu yap",
      'image': 'assets/onboarding2.png',
    },
    {
      "title": "Saha Değerlendirmeleri",
      "description": "En iyi sahaları keşfet",
      'image': 'assets/onboarding1.png',
    },
    {
      "title": "Maç Organizasyonu",
      "description": "Takımını kur, rakip bul (Çok Yakında!)",
      'image': 'assets/coming_soon_players2.png',
    },
  ];

  bool isConnectedToInternet = false;
  StreamSubscription? _internetConnectionStreamSubscription;
  int currentFeatureIndex = 0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _internetConnectionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background particles
              ...List.generate(20, (index) => _buildParticle()),

              Column(
                children: [
                  // 1) Başlık
                  Padding(
                    padding: EdgeInsets.all(20.r),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;

                        // cihaz genişliğine göre boyut hesaplama
                        double titleSize;
                        double subtitleSize;
                        if (width > 400) {
                          // büyük ekran (örneğin tablet veya geniş telefon)
                          titleSize = 46.sp;
                          subtitleSize = 18.sp;
                        } else if (width > 320) {
                          // orta seviye cihazlar
                          titleSize = 40.sp;
                          subtitleSize = 16.sp;
                        } else {
                          // küçük ekran (örneğin iPhone SE, küçük Android)
                          titleSize = 34.sp;
                          subtitleSize = 14.sp;
                        }

                        return Column(
                          children: [
                            Text(
                              'Toplansın',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8.r,
                                    color: Colors.black26,
                                    offset: Offset(1.5.w, 1.5.h),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'Yeşil Sahalarda Buluşmanın Adresi',
                              style: TextStyle(
                                fontSize: subtitleSize,
                                color: Colors.white70,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),

                  ),

                  // 2) Carousel
                  Expanded(
                    flex:2,
                    child: PageView.builder(
                      itemCount: features.length,
                      controller: PageController(viewportFraction: 0.78),
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) =>
                          setState(() => currentFeatureIndex = i),
                      itemBuilder: (_, i) {
                        return Transform.scale(
                          scale: i == currentFeatureIndex ? 1 : 0.9,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                            child: AspectRatio(
                              aspectRatio: 1.15, // biraz yatay kısaltıldı
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22.r),
                                  color: Colors.white.withOpacity(0.13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22.r),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // 🔹 Görsel
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 14.h),
                                          child: FractionallySizedBox(
                                            widthFactor: 0.65, // genişlik, görsel büyüdü
                                            child: Image.asset(
                                              features[i]['image']!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 🔹 Alt gradient overlay (yazılar için kontrast)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          height: 70.h,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.20),
                                                Colors.black.withOpacity(0.30),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 🔹 Metinler
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding:
                                          EdgeInsets.only(bottom: 16.h, left: 14.w, right: 14.w),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                features[i]['title']!,
                                                style: AppTextStyles.bodyMedium.copyWith(
                                                  fontSize: 19.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                        blurRadius: 6,
                                                        color: Colors.black.withOpacity(0.5))
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(height: 6.h),
                                              Text(
                                                features[i]['description']!,
                                                style: AppTextStyles.bodySmall.copyWith(
                                                  fontSize: 13.sp,
                                                  color: Colors.white.withOpacity(0.92),
                                                  height: 1.3,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );

                      },
                    ),
                  ),

                  // 3) Butonlar
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;

                          // SABİT BOYUT (cihazlar arası tutarlı)
                          const double BASE_WIDTH  = 340.0;
                          const double BASE_HEIGHT = 54.0;

                          // Ekran darsa 340 yerine ekran genişliğini kullan
                          final double btnWidth  = w < BASE_WIDTH ? w : BASE_WIDTH;
                          final double btnHeight = BASE_HEIGHT;

                          // Sabit tipografi/ikon (yüksekliğe göre hafif uyumlu)
                          final double iconSize  = 20.0;
                          final double labelSize = 16.0;
                          final BorderRadius radius = BorderRadius.circular(28);

                          Widget wrap(Widget child) => SizedBox(width: btnWidth, height: btnHeight, child: child);

                          final loginStyle = ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(horizontal: 16), // sabit
                            shape: RoundedRectangleBorder(borderRadius: radius),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );

                          final signupStyle = OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white70, width: 1.2),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: radius),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // GİRİŞ
                              wrap(
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (ctx, anim, _) => LoginPage(),
                                        transitionsBuilder: (ctx, anim, _, child) {
                                          final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                              .chain(CurveTween(curve: Curves.easeOut))
                                              .animate(anim);
                                          final fade = CurvedAnimation(parent: anim, curve: Curves.easeIn);
                                          return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.login_outlined, color: AppColors.primaryDark, size: iconSize),
                                  label: Text('Giriş Yap',
                                      style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w500, color: AppColors.primaryDark)),
                                  style: loginStyle,
                                ),
                              ),

                              SizedBox(height: 12),

                              // KAYIT
                              wrap(
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (ctx, anim, _) => SignUpPage(),
                                        transitionsBuilder: (ctx, anim, _, child) {
                                          final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                              .chain(CurveTween(curve: Curves.easeOut))
                                              .animate(anim);
                                          final fade = CurvedAnimation(parent: anim, curve: Curves.easeIn);
                                          return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.person_add_outlined, color: Colors.white, size: iconSize),
                                  label: Text('Kayıt Ol',
                                      style: TextStyle(color: Colors.white, fontSize: labelSize, fontWeight: FontWeight.w500)),
                                  style: signupStyle,
                                ),
                              ),

                              SizedBox(height: 16),

                              Text('Ya da Hemen Şimdi',
                                  style: TextStyle(color: Colors.white70, fontSize: 12.sp, height: 1.2)),

                              SizedBox(height: 8),

                              // Keşfet butonunu da aynı sabit genişlikte yapalım
                              wrap(
                                ExploreNowButton(
                                  onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExplorePitchesPage()));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),





                  // 4) Footer
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Column(
                      children: [
                        Text(
                          'Toplansın ile futbol keyfi bir tık uzağınızda!',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12.sp),
                        ),
                        SizedBox(height: 10.h),
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: _animation.value * 2 * math.pi,
                              child: child,
                            );
                          },
                          child: Icon(Icons.sports_soccer,
                              color: Colors.white30, size: 24.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticle() {
    final random = math.Random();
    final size = random.nextInt(10).toDouble() + 5;
    final speed = random.nextInt(20).toDouble() + 10;
    final initialPosition = random.nextDouble() * 400;
    return Positioned(
      left: random.nextDouble() * MediaQuery.of(context).size.width,
      top: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              0,
              initialPosition + (_animation.value * speed * 10) - 50,
            ),
            child: child,
          );
        },
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
// imports üstte kalsın
// import 'package:material_symbols/material_symbols.dart'; // kullanıyorsan

class ExploreNowButton extends StatelessWidget {
  final VoidCallback onTap;
  const ExploreNowButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28.r),
      onTap: onTap,
      child: Container(
        width: 350.w,
        height: 56.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2962FF), // turkuaz (Cyan 600)
            Color(0xFF00B8D4), // koyu mavi (Blue A700)
          ],
            stops: [
              0.2,  // koyu başlar
              1.0,  // 0.70–1.0 arası koyudan turkuaza yumuşak geçiş
            ],
        ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2962FF).withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // material_symbols kullanıyorsan:
                // Icon(Symbols.explore, size: 22, color: Colors.white, weight: 700, grade: 200)
                const Icon(Icons.explore, size: 22, color: Colors.white),
                SizedBox(width: 10.w),
                Text(
                  'Sahaları Keşfet',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            Spacer(),
            Container(
              width: 42.h,
              height: 42.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 22,
                color: Colors.white,
                // Symbols kullanıyorsan weight/grade ekleyebilirsin
              ),
            ),
          ],
        ),
      ),
    );
  }
}


