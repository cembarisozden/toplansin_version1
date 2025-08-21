import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Beklemedeki rezervasyonları dinler.
/// Her değişimde onCountUpdated ile güncel sayıyı gönderir.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
listenToReservationRequests({
  required String haliSahaId,
  required void Function(int count) onCountUpdated,
  bool includeMetadataChanges = false,
}) {
  return FirebaseFirestore.instance
      .collection("reservations")
      .where("haliSahaId", isEqualTo: haliSahaId)
      .where("status", isEqualTo: 'Beklemede')
      .snapshots(includeMetadataChanges: includeMetadataChanges)
      .listen((snap) {
    onCountUpdated(snap.docs.length);
  });
}

/// Beklemedeki abonelikleri dinler.
/// Her değişimde onCountUpdated ile güncel sayıyı gönderir.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
listenToSubscriptionRequests({
  required String haliSahaId,
  required void Function(int count) onCountUpdated,
  bool includeMetadataChanges = false,
}) {
  return FirebaseFirestore.instance
      .collection("subscriptions")
      .where("haliSahaId", isEqualTo: haliSahaId)
      .where("status", isEqualTo: 'Beklemede')
      .snapshots(includeMetadataChanges: includeMetadataChanges)
      .listen((snap) {
    onCountUpdated(snap.docs.length);
  });
}
