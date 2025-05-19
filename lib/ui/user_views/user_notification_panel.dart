import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';

class UserNotificationPanel extends StatefulWidget {
  const UserNotificationPanel({Key? key}) : super(key: key);

  @override
  _UserNotificationPanelState createState() => _UserNotificationPanelState();
}

class _UserNotificationPanelState extends State<UserNotificationPanel> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;

  final List<Map<String, String>> _notifications = [];

  List<Reservation> userReservations = [];

  void listenReservations(String userId) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final provider = Provider.of<UserNotificationProvider>(
        context, listen: false);

    // 1) "YYYY-MM-DD" biçiminde 'bugün' string’i oluştur
    var today = TimeService.now();
    var todayString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    // 2) Firestore’da sadece gün bazlı kıyaslama yap
    var reservationsStream = FirebaseFirestore.instance
        .collection("reservations")
        .where("userId", isEqualTo: userId)
        .where("status", whereIn: ['Onaylandı', 'İptal Edildi'])
        .where("lastUpdatedBy", isEqualTo: "owner")
        .where(
      "reservationDateTime",
      isGreaterThanOrEqualTo: todayString, // "2024-12-21" gibi
    )
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      provider.setCount(count);
    });


    // 3) Dinleme (subscription) başlat
    _reservationsSubscription = FirebaseFirestore.instance
        .collection("reservations")
        .where("userId", isEqualTo: userId)
        .where("status", whereIn: ['Onaylandı', 'İptal Edildi'])
        .where("lastUpdatedBy", isEqualTo: "owner")
        .where("reservationDateTime", isGreaterThanOrEqualTo: todayString)
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      provider.setCount(count);

      List<Reservation> reservations = [];
      List<Map<String, String>> notifications = [];

      for (var doc in snapshot.docs) {
        var reservation = Reservation.fromDocument(doc);
        reservations.add(reservation);

        notifications.add({
          "title": reservation.status == "Onaylandı"
              ? "Rezervasyon Onaylandı"
              : "Rezervasyon İptal Edildi",
          "subtitle":
          "${reservation
              .reservationDateTime} tarihli halı saha rezervasyonunuz ${reservation
              .status.toLowerCase()}.",
        });
      }

      setState(() {
        userReservations = reservations;
        _notifications
          ..clear()
          ..addAll(notifications);
      });
    });
  }


    @override
  void initState() {
    super.initState();
    // Kullanıcı oturum açmış olmalı, null kontrolü yapabilirsiniz
    var currentUser = _auth.currentUser;
    if (currentUser != null) {
      listenReservations(currentUser.uid);
    }
  }

  @override
  void dispose() {
    _reservationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Panelin yüksekliğini dinamik yapabilirsiniz.
      // Aşağıdaki örnek ekranın %50'si kadar açar.
      height: MediaQuery.of(context).size.height * 0.50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Üstte sürükleme çubuğu (modern görünüm için)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Text(
            "Bildirimler",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: _notifications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off,
                      size: 50, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text(
                    "Bildirim yok",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications,
                          color: Colors.green),
                      title: Text(
                        item['title'] ?? "",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold), // Şık bir görünüm için bold yazı
                      ),
                      subtitle: Text(item['subtitle'] ?? ""),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserReservationDetailPage(
                                reservation: userReservations[index]),
                          ),
                        ).then((_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                 UserReservationsPage()),
                          );
                        });
                      },
                    ),
                    const Divider(
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
