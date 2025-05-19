import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';

class MainPage extends StatefulWidget {
  final Person currentUser;

  MainPage({required this.currentUser});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int secilenIndex = 0;
  List<HaliSaha> favoriteHaliSahalar = [];
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;
  List<Reservation> userReservations = [];
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _reservationsSubscription?.cancel();
    super.dispose();
  }



  void _onItemTapped(int index) {
    setState(() {
      secilenIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = context.watch<UserNotificationProvider>().notificationCount;
    List<Widget> sayfalar = [
      HaliSahaPage(
        currentUser: widget.currentUser,
        favoriteHaliSahalar: favoriteHaliSahalar,
        notificationCount: count,
      ),
      FavorilerPage(
        currentUser: widget.currentUser,
        favoriteHaliSahalar: favoriteHaliSahalar,
        notificationCount: count,
      ),
    ];

    return Scaffold(
      body: sayfalar[secilenIndex],
      bottomNavigationBar: Container(
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
      ),
    );
  }
}
