import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/core/providers/bottomNavProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/ui/user_views/coming_soon_page.dart';
import 'package:toplansin/ui/user_views/dashboard_body.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_bars/toplansin_app_bar.dart';
import 'package:toplansin/ui/user_views/user_notification_page.dart';
import 'package:toplansin/ui/user_views/shared/widgets/drawers/modern_drawer.dart';

class MainPage extends StatefulWidget {
  final Person currentUser;
  final user = FirebaseAuth.instance.currentUser;

  MainPage({required this.currentUser});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<HaliSaha> favoriteHaliSahalar = [];
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;
  List<Reservation> userReservations = [];
  List<Widget> sayfalar = [];


  @override
  void initState() {
    super.initState();
    sayfalar = [
      DashboardBody(user: widget.currentUser),
      HaliSahaPage(
        currentUser: widget.currentUser,
      ),
      ComingSoonPage(),

    ];

    Future.microtask(() {
      context.read<UserNotificationProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _reservationsSubscription?.cancel();
    super.dispose();
  }

  final items = <Widget>[
    Icon(
      Icons.sports_soccer,
      size: 30,
      color: Colors.green.shade700,
    ),
    Icon(Icons.favorite, size: 30),
  ];

  final List<IconData> iconList = [
    Icons.home, // Anasayfa
    Icons.calendar_month, // Rezervasyon takvimi
    Icons.notifications, // Bildirimler
    Icons.person, // Profil
  ];

  @override
  Widget build(BuildContext context) {
    final notificationCount =
        context.watch<UserNotificationProvider>().unreadCount;

    final selectedIndex=context.watch<BottomNavProvider>().index;
    return Scaffold(
      endDrawer: ModernDrawer(
          currentUser: widget.currentUser, firebaseUser: widget.user),
      appBar: ToplansinAppBar(
        notificationCount: notificationCount,
        onNotificationTap: () => _openNotificationPage(context),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: sayfalar,
      ),
      bottomNavigationBar: Container(
        width: 12,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(0), bottom: Radius.circular(0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: GNav(
          rippleColor: AppColors.primaryLight,
          // bastığında dalga efekti
          hoverColor: Colors.green.shade50,
          // hover rengi
          haptic: true,
          // titreşimli geri bildirim

          gap: 6,
          // ikon–metin arası boşluk
          iconSize: 28,
          // ikon boyutu
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          // buton iç padding

          curve: Curves.easeInOut,
          // animasyon eğrisi
          duration: const Duration(milliseconds: 100),
          // animasyon süresi

          tabBorderRadius: 16,
          // köşe yarıçapı
          tabBorder: Border.all(color: Colors.transparent),
          // inaktif tab kenarlığı
          tabActiveBorder: Border.all(
            color: Colors.green.shade700,
            width: 1.5,
          ),
          // aktif tab kenarlığı
          tabBackgroundColor: Colors.green.shade700.withOpacity(0.15),
          // seçili tab arka planı
          activeColor: AppColors.primary,
          // seçili ikon & metin
          color: AppColors.primary,
          // seçilmemiş ikon rengi
          backgroundColor: Colors.white,
          // nav bar arkası

          tabs: [
            GButton(
              icon: Ionicons.home_outline,
              text: 'Anasayfa',
            ),
            GButton(
              icon: Ionicons.search_outline,
              text: 'Keşfet',
            ),
            GButton(
              icon: Ionicons.people_outline,
              text: 'Oyuncu Bul',
            ),
          ],

          selectedIndex: selectedIndex,
          onTabChange: (index) =>
              context.read<BottomNavProvider>().setIndex(index),

        ),
      ),
    );

  }
  void _openNotificationPage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>  UserNotificationPage(currentUser:widget.currentUser,),
        transitionsBuilder: (_, animation, __, child) {
          final offset =
          Tween(begin: const Offset(1, 0), end: Offset.zero)  // sağdan
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(animation);
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

}
