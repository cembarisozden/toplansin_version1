// lib/providers/HomeProvider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';


class HomeProvider extends ChangeNotifier {
  List<HaliSaha> favoriteHaliSahalar = [];
  final _auth=FirebaseAuth.instance;

  /* ---------------- Public read-only alanlar ---------------- */
  List<HaliSaha>  featuredPitches  = [];
  Reservation?    nextReservation;
  bool            isLoading        = true;

  /* ---------------- Init ---------------- */
  Future<void> init() async {
    try {
      await Future.wait([
        _fetchFavorites(),
        /*_fetchNextReservation(),*/
      ]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /* ---------------- Firestore sorguları ---------------- */



/*  Future<void> _fetchFeatured() async {
    final snap = await FirebaseFirestore.instance
        .collection('hali_sahalar')
        .where('featured', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(5)
        .get();

    featuredPitches = snap.docs
        .map((d) => HaliSaha.fromJson(d))   // ← burada HaliSaha oluştu
        .toList();
  }*/

  Future<void> _fetchNextReservation() async {
    final snap = await FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('status', whereIn: ['Beklenen', 'Onaylandı'])
        .where('reservationDateTime',
        isGreaterThan: TimeService.now()) // gelecek tarih
        .orderBy('reservationDateTime')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      nextReservation = Reservation.fromDocument(snap.docs.first);
    }
    notifyListeners();
  }

  Future<void> _fetchFavorites() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .get();

    final data = doc.data();
    if (data == null || !(data.containsKey('favorites'))) return;

    final List<dynamic> favoritesRaw = data['favorites'];
    if (favoritesRaw.isEmpty) return;

    final favoriteIds = favoritesRaw.cast<String>(); // String listesi

    final favoritePitches = await FirebaseFirestore.instance
        .collection('hali_sahalar')
        .where(FieldPath.documentId, whereIn: favoriteIds)
        .get();

    favoriteHaliSahalar = favoritePitches.docs
        .map((d) => HaliSaha.fromJson(d.data(), d.id))
        .toList();

  }

}
