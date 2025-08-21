import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/entitiy/hali_saha.dart';

/// Uygulama genelinde favorileri yöneten ChangeNotifier.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider() {
    _listenUserDoc();
  }


  final String _userId=FirebaseAuth.instance.currentUser!.uid;
  final _db = FirebaseFirestore.instance;

  // Saklanan veriler
  List<String> _favIds = [];          // sadece ID listesi
  List<HaliSaha> _favPitches = [];    // HaliSaha nesneleri

  StreamSubscription<DocumentSnapshot>? _userSub;

  // Public erişim
  List<HaliSaha> get favorites => _favPitches;
  bool isFavorite(String sahaId) => _favIds.contains(sahaId);

  /// Favori ekle / çıkar (yalnızca ID ver).
  Future<void> toggleFavorite(String sahaId) async {
    final op = isFavorite(sahaId)
        ? FieldValue.arrayRemove([sahaId])
        : FieldValue.arrayUnion([sahaId]);
    await _db.collection('users').doc(_userId).update({'favorites': op});
  }

  // ─── Internal ────────────────────────────────────────────────────────────
  void _listenUserDoc() {
    _userSub = _db
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen((doc) async {
      _favIds = List<String>.from(doc.data()?['favorites'] ?? []);
      await _refreshObjects();
      notifyListeners();
    });
  }

  Future<void> _refreshObjects() async {
    final snap = await _db.collection('hali_sahalar').get();
    _favPitches = snap.docs
        .where((d) => _favIds.contains(d.id))
        .map((d) => HaliSaha.fromJson(d.data(), d.id))
        .toList();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
