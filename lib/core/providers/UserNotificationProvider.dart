import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/notification_model.dart';
import 'package:toplansin/data/entitiy/reservation.dart';

class UserNotificationProvider with ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<User?>? _authSub;

  List<NotificationModel> get notifications => _notifications;

  int get unreadCount =>
      _notifications
          .where((n) => n.read == false)
          .length;

  void startListening() {
    // varsa eski abonelikleri kapat
    _subscription?.cancel();
    _authSub?.cancel();

    // 1) logout'ta state temizliği (UI güncelle)
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _notifications.clear();
        notifyListeners();
      }
    });

    // 2) auth'a bağlı stream: login olunca aç, logout olunca otomatik kapanır
    _subscription = FirebaseAuth.instance
        .authStateChanges()
        .asyncExpand((user) {
      if (user == null) {
        // unauth → Firestore'a bağlanma
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    })
        .listen((snap) {
      _notifications
        ..clear()
        ..addAll(snap.docs.map(NotificationModel.fromDoc));
      notifyListeners(); // tek sefer
    }, onError: (e, st) {
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
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
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
