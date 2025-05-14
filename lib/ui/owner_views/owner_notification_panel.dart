import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';

class OwnerNotificationPanel extends StatefulWidget {
  final HaliSaha currentHaliSaha;

  OwnerNotificationPanel({required this.currentHaliSaha});

  @override
  _OwnerNotificationPanelState createState() => _OwnerNotificationPanelState();
}

class _OwnerNotificationPanelState extends State<OwnerNotificationPanel> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;

  final List<Map<String, String>> _notifications = [];

  List<Reservation> haliSahaReservations = [];

  void listenReservations(String userId) {
    var today =TimeService.now();
    var todayString =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    print("${widget.currentHaliSaha.id}");

    var reservationsStream = FirebaseFirestore.instance
        .collection("reservations")
        .where("haliSahaId", isEqualTo: widget.currentHaliSaha.id)
        .where("userId", isNotEqualTo: "")
        .where("status", whereIn: ['İptal Edildi'])
        .where("reservationDateTime",
        isGreaterThan: todayString) // Tarih kıyaslama
        .snapshots();

    _reservationsSubscription = reservationsStream.listen((snapshot) async {
      List<Reservation> reservations = [];
      for (var document in snapshot.docs) {
        var reservation = Reservation.fromDocument(document);
        reservations.add(reservation);
      }
      setState(() {
        haliSahaReservations = reservations;

        // Bildirimleri güncellemeden önce mevcut listeyi temizleyin
        _notifications.clear();

        for (var reservation in haliSahaReservations)
          if (reservation.status == "İptal Edildi")
            _notifications.add({
              "title": "Rezervasyon İptal Edildi",
              "subtitle":
              "${reservation.reservationDateTime} tarihli ${reservation.haliSahaName} rezervasyonu iptal edildi."
            });
      });
    });
  }

  @override
  void initState() {
    listenReservations(_auth.currentUser!.uid);
    super.initState();
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
              child: Text(
                "Bildirim yok",
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    ),
                    const Divider(
                      thickness: 1, // Çizgi kalınlığı
                      indent: 16, // Soldan boşluk
                      endIndent: 16, // Sağdan boşluk
                      color: Colors.grey, // Çizgi rengi
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
