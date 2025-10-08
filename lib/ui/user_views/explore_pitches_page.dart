import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';

class ExplorePitchesPage extends StatelessWidget {
  const ExplorePitchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar:
         AppBar(
        automaticallyImplyLeading: false,   // default leading’i kapat
        elevation: 6,
        centerTitle: false,                 // solda hizala
        toolbarHeight: 40,
        flexibleSpace: Container(
          decoration:  BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // ----------- LOGO + METİN (sol) -----------
        title:
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.asset('assets/logo2.png', height: 90),
            ),
            Text(
              'Toplansın',
              style: GoogleFonts.urbanist(
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: .2,
                ),
              ),
            ),
          ],
        ),
      ),
      body:HaliSahaPage(),
    );
  }
}
