import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/entitiy/hali_saha.dart';

/// Uygulama genelinde favorileri yöneten ChangeNotifier.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider() {
    _listenAuthAndUserDoc();
  }

  final _db = FirebaseFirestore.instance;

  // State
  List<String> _favIds = <String>[];
  List<HaliSaha> _favPitches = <HaliSaha>[];

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  // Public
  List<HaliSaha> get favorites => _favPitches;
  bool isFavorite(String sahaId) => _favIds.contains(sahaId);

  /// Favori ekle/çıkar – Optimistic Update
  Future<bool> toggleFavorite(String sahaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    final ref = _db.collection('users').doc(user.uid);

    final wasFav = _favIds.contains(sahaId);
    final willBeFav = !wasFav;

    // 1) OPTIMISTIC: Local state’i anında güncelle
    if (wasFav) {
      _favIds.remove(sahaId);
    } else {
      _favIds.add(sahaId);
    }
    // (İstersen burada sadece ilgili HaliSaha’yı ekleyip/çıkarıp
    // _refreshObjects() çağırmadan da güncelleyebilirsin.)
    notifyListeners();

    // 2) Sunucuya yaz (array op ile)
    try {
      await ref.update({
        'favorites': willBeFav
            ? FieldValue.arrayUnion([sahaId])
            : FieldValue.arrayRemove([sahaId]),
      });
      return willBeFav;
    } catch (e) {
      // 3) HATA: Local değişikliği GERI AL
      if (willBeFav) {
        _favIds.remove(sahaId);
      } else {
        _favIds.add(sahaId);
      }
      notifyListeners();
      rethrow;
    }
  }


  // ─── Internal ────────────────────────────────────────────────────────────

  void _listenAuthAndUserDoc() {
    // Eski abonelikleri kapat
    _authSub?.cancel();
    _userSub?.cancel();

    // Auth değişimini dinle
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // Her auth değişiminde userDoc stream’i yeniden bağla
      await _bindUserDocStream(user);
      if (user == null) {
        // Çıkışta state’i temizle
        _favIds = const <String>[];
        _favPitches = const <HaliSaha>[];
        notifyListeners();
      }
    });
  }

  Future<void> _bindUserDocStream(User? user) async {
    // Öncekini kapat
    await _userSub?.cancel();
    _userSub = null;

    if (user == null) return;

    _userSub = _db.collection('users').doc(user.uid).snapshots().listen(
          (doc) async {
        _favIds = List<String>.from(doc.data()?['favorites'] ?? const <String>[]);
        await _refreshObjects();
        notifyListeners();
      },
      onError: (e, st) => debugPrint('user doc stream error: $e'),
    );
  }

  Future<void> _refreshObjects() async {
    if (_favIds.isEmpty) {
      _favPitches = const <HaliSaha>[];
      return;
    }
    // İstersen sadece gereken ID’leri çek: where(FieldPath.documentId, whereIn: chunks)
    final snap = await _db.collection('hali_sahalar').get();
    _favPitches = snap.docs
        .where((d) => _favIds.contains(d.id))
        .map((d) => HaliSaha.fromJson(d.data(), d.id))
        .toList();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
