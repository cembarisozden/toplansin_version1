import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';


class ToplansinAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ToplansinAppBar({
    super.key,
    required this.notificationCount,
    required this.onNotificationTap,
  });

  final int        notificationCount;
  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(70);   // ↑ biraz yüksek

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,   // default leading’i kapat
      elevation: 6,
      centerTitle: false,                 // solda hizala
      toolbarHeight: 90,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
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

      // ----------- İKİ İKON DA SAĞDA -----------
      actions: [
        // Bildirim
        Stack(
          children: [
            IconButton(
              icon: const Icon(Ionicons.notifications_outline, color: Colors.white,size: 25,),
              onPressed: onNotificationTap,
            ),
            if (notificationCount > 0)
              Positioned(
                right: 6,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 18, minHeight: 18),
                  child: Text(
                    '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // Menü (drawer)
        IconButton(
          icon: const Icon(Ionicons.menu_outline, color: Colors.white,size: 30,),
          onPressed: () => Scaffold.of(context).openEndDrawer(),          // dışarıdan Scaffold.of(context).openDrawer()
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
