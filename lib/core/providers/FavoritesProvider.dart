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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<User?>? _authSub;

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
    // Eski abonelikleri kapat (idempotent)
    _userSub?.cancel();
    _authSub?.cancel();

    // 1) Auth değişimini dinle: çıkışta state'i temizle
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        // Oturum kapandı → user-scoped state'i temizle
        _favIds = const <String>[];
        await _refreshObjects();
        notifyListeners();
      }
    });

    // 2) User-scoped stream: auth’a göre Firestore dinlemesini aç/kapa
    _userSub = FirebaseAuth.instance
        .authStateChanges()
        .asyncExpand((user) {
      if (user == null) {
        // Una uth → Firestore'a bağlanma
        return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
      }
      return _db
          .collection('users')
          .doc(user.uid) // _userId yerine daima canlı auth uid
          .snapshots();
    })
        .listen((doc) async {
      _favIds = List<String>.from(doc.data()?['favorites'] ?? const <String>[]);
      await _refreshObjects();
      notifyListeners();
    }, onError: (e, st) {
      debugPrint('user doc stream error: $e');
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
