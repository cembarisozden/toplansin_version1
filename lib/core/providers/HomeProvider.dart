// lib/providers/HomeProvider.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/data/entitiy/reviews.dart';
import 'package:toplansin/services/time_service.dart';

class HomeProvider extends ChangeNotifier {
  List<HaliSaha> favoriteHaliSahalar = [];
  List<HaliSaha> trendHaliSahalar = [];
  final _auth = FirebaseAuth.instance;

  /* ---------------- Public read-only alanlar ---------------- */
  List<HaliSaha> featuredPitches = [];
  Reservation? nextReservation;
  bool isLoading = true;

  /* ---------------- Init ---------------- */
  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      await _fetchFavorites();
      // Parametresiz olarak bütün sahaları çekip trend’e göre sırala
      trendHaliSahalar = await sortByTrend();
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



  Future<List<HaliSaha>> sortByTrend() async {
    final now = TimeService.now();

    // 1) Tüm sahaları çek
    final allSnap = await FirebaseFirestore.instance
        .collection('hali_sahalar')
        .get();
    final allPitches = allSnap.docs
        .map((d) => HaliSaha.fromJson(d.data(), d.id))
        .toList();

    // 2) Her saha için yorumları çek ve skor hesapla
    final futures = allPitches.map((p) async {
      final revSnap = await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(p.id)
          .collection('reviews')
          .get();

      final reviews = revSnap.docs.map((d) {
        final data = d.data();
        return Reviews(
          docId:     d.id,
          comment:   data['comment']   as String,
          rating:    (data['rating']   as num).toDouble(),
          datetime:  (data['datetime'] as Timestamp).toDate(),
          userId:    data['userId']    as String,
          user_name: data['user_name'] as String,
        );
      }).toList();

      final count = reviews.length;
      final avg = count == 0
          ? 0.0
          : reviews.map((r) => r.rating).reduce((a, b) => a + b) / count;

      double recencyFactor = 1.0;
      if (count > 0) {
        final last = reviews
            .map((r) => r.datetime)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final days = now.difference(last).inDays + 1;
        recencyFactor = 1 / sqrt(days);
      }

      final score = avg * log(count + 1) * recencyFactor;
      return MapEntry(p, score);
    }).toList();

    // 3) Sonuçları bekle, skora göre sırala ve sadece listeyi dön
    final scored = await Future.wait(futures)
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }


}
