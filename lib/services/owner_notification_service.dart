import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

/// Beklemedeki rezervasyonları dinler.
/// Her değişimde onCountUpdated ile güncel sayıyı gönderir.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>> listenToReservationRequests({
  required String haliSahaId,
  required void Function(int count) onCountUpdated,
  bool includeMetadataChanges = false,
}) {
  int lastCount = -1;

  final stream = FirebaseAuth.instance
      .authStateChanges()
      .asyncExpand((user) {
    if (user == null) {
      // Oturum kapalıyken Firestore’a bağlanma + UI’ı sıfırla
      Future.microtask(() => onCountUpdated(0));
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    // (Gerekirse role/owner kontrolünü burada ekleyebilirsin)
    return FirebaseFirestore.instance
        .collection("reservations")
        .where("haliSahaId", isEqualTo: haliSahaId)
        .where("status", isEqualTo: 'Beklemede')
        .snapshots(includeMetadataChanges: includeMetadataChanges);
  });

  return stream.listen(
        (snap) {
      final count = snap.docs.length;
      if (count != lastCount) {
        lastCount = count;
        onCountUpdated(count);
      }
    },
    onError: (e, st) {
      // permission-denied vs. UI'yı düşürme
      debugPrint('listenToReservationRequests error: $e');
    },
  );
}

/// Beklemedeki abonelikleri dinler.
/// Her değişimde onCountUpdated ile güncel sayıyı gönderir.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>> listenToSubscriptionRequests({
  required String haliSahaId,
  required void Function(int count) onCountUpdated,
  bool includeMetadataChanges = false,
}) {
  int lastCount = -1;

  final stream = FirebaseAuth.instance
      .authStateChanges()
      .asyncExpand((user) {
    if (user == null) {
      // Oturum kapalı → Firestore'a bağlanma, UI'ı sıfırla
      Future.microtask(() => onCountUpdated(0));
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    // Gerekirse burada role/owner kontrolü ekleyebilirsin (rule'larla uyumlu olmalı).
    return FirebaseFirestore.instance
        .collection("subscriptions")
        .where("haliSahaId", isEqualTo: haliSahaId)
        .where("status", isEqualTo: 'Beklemede')
        .snapshots(includeMetadataChanges: includeMetadataChanges);
  });

  return stream.listen(
        (snap) {
      final count = snap.docs.length;
      if (count != lastCount) {
        lastCount = count;
        onCountUpdated(count);
      }
    },
    onError: (e, st) {
      // permission-denied v.b. durumlarda UI düşmesin
      debugPrint('listenToSubscriptionRequests error: $e');
    },
  );
}