import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/notification_model.dart';
import 'package:toplansin/data/entitiy/reservation.dart';

class UserNotificationProvider with ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription? _sub;
  List<NotificationModel> get notifications => _notifications;

  int get unreadCount =>
      _notifications
          .where((n) => n.read == false)
          .length;




  void startListening() {
    _sub?.cancel();

    _sub = FirebaseAuth.instance
        .authStateChanges()
        .map((u) => u?.uid)
        .distinct()
        .switchMap((uid) {
      if (uid == null) {
        // auth yok → boş stream (her şeyi kapatır)
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    })
        .listen((snap) {
      _notifications
        ..clear()
        ..addAll(snap.docs.map(NotificationModel.fromDoc));
      notifyListeners();
    }, onError: (e, st) {
      // signOut yarıda yakalanırsa gelen permission-denied’ı sessiz yut
      debugPrint('notifications stream error: $e');
    });
  }



  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
    });
  }

  Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1️⃣ Okunmamışları topluca çek
    final qSnap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    if (qSnap.docs.isEmpty) return;

    // 2️⃣ Batch ile hepsini tek istekle güncelle
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in qSnap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit(); // 🔥 tek round‑trip
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }


  Future<Reservation> userReservation({required String userId ,required String reservationId}) async {
    var doc = await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .get();
    if (!doc.exists) {
      print("${reservationId} , ${userId} ");
      final logSnapshot = await FirebaseFirestore.instance
          .collection('reservation_logs')
          .where('userId', isEqualTo: userId)
          .where('reservationId', isEqualTo: reservationId)
          .orderBy('createdAt',descending: true)
          .limit(1)
          .get();
      if (logSnapshot.docs.isEmpty) {
        throw AppErrorHandler.getMessage("Rezervasyon Bulunamadı");
      }
      doc = logSnapshot.docs.first;
    }
    if(!doc.exists){
      throw AppErrorHandler.getMessage("Rezervasyon Bulunamadı");
    }

    return Reservation.fromDocument(doc);
  }

}
