import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/notification_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_page.dart';

class MainPage extends StatefulWidget {
  final Person currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MainPage({required this.currentUser});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int secilenIndex = 0;
  List<HaliSaha> favoriteHaliSahalar = [];
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;
  final List<Map<String, String>> _notifications = [];
  List<Reservation> userReservations = [];

  @override
  void initState() {
    super.initState();
    // iOS & Android bildirim izinleri
    listenReservations(widget.currentUser.id);
  }

  @override
  void dispose() {
    _reservationsSubscription?.cancel();
    super.dispose();
  }




  void listenReservations(String userId) {
    var today =TimeService.now();
    var todayString =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    var reservationsStream = FirebaseFirestore.instance
        .collection("reservations")
        .where("userId", isEqualTo: userId)
        .where("status", whereIn: ['Onaylandı', 'İptal Edildi'])
        .where("reservationDateTime",
            isGreaterThan: todayString) // Tarih kıyaslama
        .snapshots();

    _reservationsSubscription = reservationsStream.listen((snapshot) {
      List<Reservation> reservations = [];
      List<Map<String, String>> newNotifications = [];

      for (var document in snapshot.docs) {
        var reservation = Reservation.fromDocument(document);
        reservations.add(reservation);
        if (reservation.status == "Onaylandı") {
          newNotifications.add({
            "title": "Rezervasyon Onaylandı",
            "subtitle":
                "${reservation.reservationDateTime} tarihli halı saha rezervasyonunuz onaylandı."
          });
        } else {
          newNotifications.add({
            "title": "Rezervasyon İptal Edildi",
            "subtitle":
                "${reservation.reservationDateTime} tarihli halı saha rezervasyonunuz iptal edildi."
          });
        }
      }

      setState(() {
        userReservations = reservations;
        _notifications.clear();
        _notifications.addAll(newNotifications);
      });
    }, onError: (error) {
      print('Dinleme hatası: $error');
      // Hata durumunda yapılacak işlemler
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      secilenIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> sayfalar = [
      HaliSahaPage(
        currentUser: widget.currentUser,
        favoriteHaliSahalar: favoriteHaliSahalar,
        notificationCount: _notifications.length,
      ),
      FavorilerPage(
        currentUser: widget.currentUser,
        favoriteHaliSahalar: favoriteHaliSahalar,
        notificationCount: _notifications.length,
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
