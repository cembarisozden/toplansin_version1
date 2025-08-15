import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import '../user_views/shared/theme/app_colors.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Güvenli kare görsel boyutu (ekran genişliği/ yüksekliği dikkate alınır)
    final double imgSide = math.min(0.6.sw, 0.35.sh).clamp(160.w, 340.w);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),

                // Görsel ekran boyutuna göre ölçeklenir
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SizedBox.square(
                      dimension: imgSide,
                      child: Image.asset(
                        'assets/coming_soon_players2.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Başlık
                Text(
                  'Oyuncu mu Arıyorsun?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),

                SizedBox(height: 10.h),

                // Açıklama
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    'Takımın eksik mi kaldı? Oyuncu bulmak artık çok kolay olacak! '
                        'Bu özellikle yakında buradayız 🚀',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16.sp,
                      height: 1.35,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),

                SizedBox(height: 18.h),

                // "Yakında" rozeti — FittedBox ile dar ekranlarda otomatik küçülür
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(32.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 20.sp, color: Colors.white),
                        SizedBox(width: 8.w),
                        Text(
                          'YAKINDA HİZMETİNİZDE',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.1,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.star_rounded, size: 20.sp, color: Colors.white),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
