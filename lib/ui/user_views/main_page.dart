import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/ui/user_views/coming_soon_page.dart';
import 'package:toplansin/ui/user_views/dashboard_body.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_bars/toplansin_app_bar.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';
import 'package:toplansin/ui/user_views/user_notification_panel.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';
import 'package:toplansin/ui/user_views/user_settings_page.dart';
import 'package:toplansin/ui/user_views/shared/widgets/drawers/modern_drawer.dart';
import 'package:toplansin/ui/views/login_page.dart';

class MainPage extends StatefulWidget {
  final Person currentUser;
  final user = FirebaseAuth.instance.currentUser;

  MainPage({required this.currentUser});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int secilenIndex = 0;
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
      Provider.of<UserNotificationProvider>(context, listen: false)
          .startListening();
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
        context.watch<UserNotificationProvider>().totalCount;
    return Scaffold(
      endDrawer: ModernDrawer(
          currentUser: widget.currentUser, firebaseUser: widget.user),
      appBar: ToplansinAppBar(
        notificationCount: notificationCount,
        onNotificationTap: () async {
          await _showNotificationPanel(context); // panel kapandığında devam et
        },
      ),
      body: IndexedStack(
        index: secilenIndex,
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
              top: Radius.circular(24), bottom: Radius.circular(24)),
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

          selectedIndex: secilenIndex,
          onTabChange: (index) => setState(() => secilenIndex = index),
        ),
      ),
    );

    /*bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_soccer),
              label: 'Halı Sahalar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favorilerim',
            ),
          ],
          currentIndex: secilenIndex,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade600,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 14,
          unselectedFontSize: 12,
        ),
      ),*/
  }

  /// BigEagle tarzı yan menüyü ve ana içeriği tek bir Row içinde

  Future<void> _showNotificationPanel(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return UserNotificationPanel(
          currentUser: widget.currentUser,
        );
      },
    );
  }

  /// Returns a widget containing the animated sidebar and expanded content.

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey.shade100,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            /// Header
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF4CBB17), // dark green
                    Color(0xFF48872B4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Ionicons.person_outline,
                        color: Colors.green.shade700, size: 40),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.currentUser.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(widget.user?.email ?? "",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            /// Rezervasyonlarım

            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.green.shade700),
              title: Text("Rezervasyonlarım",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => UserReservationsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.event_repeat,
                color: Colors.blue.shade700,
              ),
              title: Text("Aboneliklerim",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SubscriptionDetailPage(
                            currentUser: widget.currentUser,
                          )),
                );
              },
            ),

            /// Ayarlar
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey.shade700),
              title: Text("Ayarlar",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserSettingsPage(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
            ),

            Divider(),

            /// Çıkış Yap
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Çıkış Yap",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.red)),
              onTap: () async {
                if (widget.user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.user?.uid)
                      .update({
                    'fcmToken': FieldValue.delete(),
                  });
                }
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
