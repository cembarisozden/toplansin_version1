// lib/core/theme/app_text_styles.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uygulama genelinde kullanılan metin stilleri.
/// Başlıklar için Poppins, gövde ve butonlar için Inter fontları tercih edilmiştir.
/// Modern, minimalist bir tasarım hiyerarşisi sunar.
class AppTextStyles {

  /// displayLarge: Ana ekranın en üstündeki büyük başlıklar için kullanılır. (36sp)
  /// Örnek: Hoşgeldiniz ekranı başlığı, ana sayfa başlığı.
  static final displayLarge = GoogleFonts.poppins(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.2,
  );

  /// displayMedium: İkincil büyük başlıklar için kullanılır. (28sp)
  /// Örnek: Bölüm başlıkları, sekme başlıkları.
  static final displayMedium = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// titleLarge: Ana içerik başlıkları için kullanılır. (24sp)
  /// Örnek: Sayfa alt başlıkları, form başlıkları.
  static final titleLarge = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// titleMedium: Alt başlıklar veya bölüm ara başlıkları için kullanılır. (20sp)
  /// Örnek: Kart başlıkları, liste başlıkları.
  static final titleMedium = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// bodyLarge: Ana içerik metinleri için kullanılır. (18sp)
  /// Örnek: Uzun paragraf metinleri, açıklamalar.
  static final bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// bodyMedium: Standart gövde metni için kullanılır. (16sp)
  /// Örnek: Form etiketleri, liste açıklamaları.
  static final bodyMedium = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// bodySmall: İkincil küçük metinler, dipnotlar için kullanılır. (14sp)
  /// Örnek: Yardım metinleri, tarih/bilgi satırları.
  static final bodySmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// labelLarge: Büyük buton metinleri ve etiketler için kullanılır. (16sp)
  /// Örnek: Birincil buton yazıları, sekme etiketleri.
  static final labelLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// labelMedium: Orta boy buton metinleri veya küçük etiketler için. (14sp)
  /// Örnek: İkincil buton yazıları, list filter etiketleri.
  static final labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    height: 1.2,
  );

  /// labelSmall: Çok küçük metinler, yardımcı etiketler için. (12sp)
  /// Örnek: Tarih etiketleri, ikon altı açıklamalar.
  static final labelSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.2,
  );

  /// Creates a TextTheme for global override in ThemeData
  /// ThemeData içinde `textTheme: AppTextStyles.textTheme` olarak eklenebilir.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
