import 'package:flutter/material.dart';
import '../user_views/shared/theme/app_colors.dart';

/// 𝗢𝘆𝘂𝗻𝗰𝘂 𝗕𝘂𝗹 ─ Tanıtım (Coming-Soon) Ekranı
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Yumuşak gri-mavi degrade arka plan ────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF1F5F9), // açık gri-mavi
              Color(0xFFE2E8F0), // biraz daha koyu
            ],
          ),
        ),
        // ── İçerik ───────────────────────────────────────────────────────────
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // İlustrasyon
                Image.asset(
                  'assets/coming_soon_players2.png',
                  width: 320,
                  height: 320,
                ),

                const SizedBox(height: 32),

                // Başlık
                Text(
                  'Oyuncu mu Arıyorsun?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),

                const SizedBox(height: 18),

                // Açıklama
                Text(
                  'Takımın eksik mi kaldı? Oyuncu bulmak artık çok kolay olacak! '
                      'Bu özellikle yakında buradayız 🚀',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 32),

                // Yakında rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF34D399),  // açık yeşil
                        Color(0xFF059669),  // koyu yeşil
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 20, color: Colors.white),          // sol ikon
                      const SizedBox(width: 8),
                      Text(
                        'YAKINDA HİZMETİNİZDE',
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 20, color: Colors.white),          // sağ ikon
                    ],
                  ),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}
