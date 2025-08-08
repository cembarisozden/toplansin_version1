// lib/core/theme/app_text_styles.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sade, modern ve göz yormayan metin stilleri.
/// Roboto tercih edilmiştir: düz ve okunabilir.
/// Fontlar artık daha küçük ve kullanılabilir boyutlarda.
class AppTextStyles {
  // Başlıklar
  static final titleLarge = GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static final titleMedium = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static final titleSmall = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  // Gövde metinleri (paragraflar, açıklamalar)
  static final bodyLarge = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static final bodyMedium = GoogleFonts.roboto(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static final bodySmall = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Etiketler ve buton yazıları
  static final labelLarge = GoogleFonts.roboto(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static final labelMedium = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static final labelSmall = GoogleFonts.roboto(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.2,
  );

  // Global ThemeData desteği için TextTheme
  static TextTheme get textTheme => TextTheme(
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
