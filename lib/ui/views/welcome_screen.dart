import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toplansin/ui/user_views/explore_pitches_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';
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
      "icon": "⚡"
    },
    {
      "title": "Saha Değerlendirmeleri",
      "description": "En iyi sahaları keşfet",
      "icon": "⭐"
    },
    {
      "title": "Maç Organizasyonu",
      "description": "Takımını kur, rakip bul (Çok Yakında!)",
      "icon": "🏆"
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
                    child: Column(
                      children: [
                        Text(
                          'Toplansın',
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                  blurRadius: 10.r,
                                  color: Colors.black26,
                                  offset: Offset(2.w, 2.h)),
                            ],
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'Yeşil Sahalarda Buluşmanın Adresi',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // 2) Carousel
                  Expanded(
                    flex: 2,
                    child: PageView.builder(
                      itemCount: features.length,
                      controller: PageController(viewportFraction: 0.8),
                      onPageChanged: (i) =>
                          setState(() => currentFeatureIndex = i),
                      itemBuilder: (_, i) {
                        return Transform.scale(
                          scale: i == currentFeatureIndex ? 0.95 : 0.85,
                          child: Card(
                            color: Colors.white,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.r)),
                            child: Container(
                              padding: EdgeInsets.all(20.r),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(features[i]['icon']!,
                                      style: TextStyle(fontSize: 50.sp)),
                                  SizedBox(height: 20.h),
                                  Text(
                                    features[i]['title']!,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    features[i]['description']!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 14.sp,
                                        color: AppColors.primary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 350.w,
                            height: 56.h,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (ctx, anim, sec) =>
                                       LoginPage(),
                                    transitionsBuilder:
                                        (ctx, anim, sec, child) {
                                      final slide = Tween<Offset>(
                                              begin: const Offset(1, 0),
                                              end: Offset.zero)
                                          .chain(
                                              CurveTween(curve: Curves.easeOut))
                                          .animate(anim);
                                      final fade = CurvedAnimation(
                                          parent: anim, curve: Curves.easeIn);
                                      return SlideTransition(
                                        position: slide,
                                        child: FadeTransition(
                                            opacity: fade, child: child),
                                      );
                                    },
                                    transitionDuration:
                                        const Duration(milliseconds: 400),
                                  ),
                                );
                              },
                              icon: Icon(Icons.login_outlined,
                                  color: AppColors.primaryDark, size: 24.sp),
                              label: Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.black26,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: 350.w,
                            height: 56.h,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (ctx, anim, sec) =>
                                        SignUpPage(),
                                    transitionsBuilder:
                                        (ctx, anim, sec, child) {
                                      final slide = Tween<Offset>(
                                              begin: const Offset(1, 0),
                                              end: Offset.zero)
                                          .chain(
                                              CurveTween(curve: Curves.easeOut))
                                          .animate(anim);
                                      final fade = CurvedAnimation(
                                          parent: anim, curve: Curves.easeIn);
                                      return SlideTransition(
                                        position: slide,
                                        child: FadeTransition(
                                            opacity: fade, child: child),
                                      );
                                    },
                                    transitionDuration:
                                        const Duration(milliseconds: 400),
                                  ),
                                );
                              },
                              icon: Icon(Icons.person_add_outlined,
                                  color: Colors.white, size: 24.sp),
                              label: Text(
                                'Kayıt Ol',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.white70, width: 2.w),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Text('Ya da Hemen Şimdi', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                          SizedBox(height: 8.h),
                          ExploreNowButton(
                            onTap: () {

                              Navigator.of(context).push(MaterialPageRoute(builder: (_) =>  ExplorePitchesPage()));

                            },
                          ),
                        ],
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
                              TextStyle(color: Colors.white70, fontSize: 14.sp),
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
                    fontWeight: FontWeight.w700,
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


