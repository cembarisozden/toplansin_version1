import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/acces_code.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/services/firebase_functions_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/user_acces_code_page.dart';

class AccessCodeProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AccessCode? activeCode;
  List<AccessCode> inactiveCodes = [];
  String? error;

  /// Sahaya ait en güncel tek aktif kodu getir
  Future<void> loadActiveCode(BuildContext context, String haliSahaId) async {
    try {
      final snap = await _db
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .collection('accessCodes')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      activeCode =
          snap.docs.isEmpty ? null : AccessCode.fromDoc(snap.docs.first);
      error = null;
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
    notifyListeners();
  }

  /// Yeni kod oluştur ve eski kodları pasifleştir
  Future<void> createCode({
    required BuildContext context,
    required String haliSahaId,
    required String ownerUid,
    required String newCode,
  }) async {
    try {
      print(ownerUid);
      final col = _db.collection('hali_sahalar').doc(haliSahaId).collection('accessCodes');
      final privateActiveRef = _db
          .collection('hali_sahalar').doc(haliSahaId)
          .collection('private').doc('active');

      final existing = await col.where('isActive', isEqualTo: true).get();
      final newDocRef = col.doc();
      final batch = _db.batch();

      // mevcut aktifleri pasifleştir
      for (var doc in existing.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      // yeni aktif kodu ekle
      batch.set(
        newDocRef,
        AccessCode(
          id: newDocRef.id,
          code: newCode,
          createdAt: TimeService.nowUtc(),
          createdBy: ownerUid,
          isActive: true,
        ).toJson(),
      );

      // 🔒 gizli aktif kod belgesini güncelle
      batch.set(privateActiveRef, {
        'code': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      await loadActiveCode(context, haliSahaId);
      await loadInactiveCodes(context, haliSahaId);
      await _cleanupInactiveCodes(haliSahaId);

      AppSnackBar.success(context, 'Yeni erişim kodu oluşturuldu.');
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
    }
    notifyListeners();
  }



  Future<void> activateCodeAgain({
    required BuildContext context,
    required String haliSahaId,
    required String codeId,
  }) async {
    try {
      final col = _db.collection('hali_sahalar').doc(haliSahaId).collection('accessCodes');
      final privateActiveRef = _db
          .collection('hali_sahalar').doc(haliSahaId)
          .collection('private').doc('active');

      final selectedRef = col.doc(codeId);
      final selectedSnap = await selectedRef.get();
      if (!selectedSnap.exists) {
        AppSnackBar.error(context, 'Kod bulunamadı.');
        return;
      }
      final selected = AccessCode.fromDoc(selectedSnap);

      final activeSnap = await col.where('isActive', isEqualTo: true).get();

      final batch = _db.batch();

      // mevcut aktifleri kapat
      for (var doc in activeSnap.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      // seçilen kodu aktifleştir
      batch.update(selectedRef, {
        'isActive': true,
        'deactivatedAt': FieldValue.delete(),
      });

      // 🔒 gizli aktif kod belgesini güncelle
      batch.set(privateActiveRef, {
        'code': selected.code,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      await loadActiveCode(context, haliSahaId);
      await loadInactiveCodes(context, haliSahaId);
      await _cleanupInactiveCodes(haliSahaId);

      AppSnackBar.success(context, 'Kod başarıyla yeniden aktifleştirildi.');
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
    }
  }



  /// Sahadaki eski (pasif) tüm kodları getir
  Future<void> loadInactiveCodes(
      BuildContext context, String haliSahaId) async {
    try {
      final snap = await _db
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .collection('accessCodes')
          .where('isActive', isEqualTo: false)
          .orderBy('deactivatedAt', descending: true)
          .get();

      inactiveCodes = snap.docs.map((d) => AccessCode.fromDoc(d)).toList();
      error = null;
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
    notifyListeners();
  }

  Future<void> _cleanupInactiveCodes(String haliSahaId, {int keep = 3}) async {
    final col = _db
        .collection('hali_sahalar')
        .doc(haliSahaId)
        .collection('accessCodes');

    // Pasifleri son pasifleştirme zamanına göre sırala (en yeni üstte)
    final snap = await col
        .where('isActive', isEqualTo: false)
        .orderBy('deactivatedAt', descending: true)
        .get();

    if (snap.docs.length <= keep) return;

    final extras = snap.docs.skip(keep); // en yeni 3’i bırak, gerisini sil
    final batch = _db.batch();
    for (final d in extras) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }


// 1) Kodla saha bulma
  Future<HaliSaha?> findPitchByCode(BuildContext context, String code) async {
    try {
      final result = await functions
          .httpsCallable('findPitchByCode')
          .call({'code': code});

      final data = Map<String, dynamic>.from(result.data ?? {});

      if (data['ok'] != true) {
        AppSnackBar.error(context, data['message'] ?? 'Geçerli bir kod bulunamadı.');
        return null;
      }

      final pitchRaw = (data['data']?['pitch'] ?? {}) as Map;
      final pitchData = Map<String, dynamic>.from(pitchRaw);
      return HaliSaha.fromJson(pitchData, pitchData['id']?.toString() ?? '');
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      return null;
    }
  }

// 2) Kullanıcıya kod ekleme
  Future<void> addUserAccessCode(BuildContext context, String codeId) async {
    try {
      final result = await functions
          .httpsCallable('addUserAccessCode')
          .call({'code': codeId});

      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['ok'] == true) {
        AppSnackBar.success(context, data['message'] ?? 'Kod hesabınıza eklendi.');
      } else {
        AppSnackBar.error(context, data['message'] ?? 'Kod eklenemedi.');
      }
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
    }
  }

// 3) Kullanıcıdan kod silme
  Future<void> removeUserAccessCode(BuildContext context, String codeId) async {
    try {
      final result = await functions
          .httpsCallable('removeUserAccessCode')
          .call({'code': codeId});

      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['ok'] == true) {
        AppSnackBar.success(context, data['message'] ?? 'Kod hesabınızdan kaldırıldı.');
      } else {
        AppSnackBar.error(context, data['message'] ?? 'Kod kaldırılamadı.');
      }
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
    }
  }

// 4) Kullanıcının kodlarını yükleme
  Future<List<UserCodeEntry>> loadUserCodes(BuildContext context) async {
    try {
      final result = await functions
          .httpsCallable('loadUserCodes')
          .call();

      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['ok'] != true) {
        AppSnackBar.error(context, data['message'] ?? 'Kodlar yüklenemedi.');
        return [];
      }

      final List list = (data['data'] ?? []) as List;
      return list.map((e) {
        final pitchRaw = e['pitch'] as Map? ?? {};
        final pitchData = Map<String, dynamic>.from(pitchRaw);
        return UserCodeEntry(
          pitch: HaliSaha.fromJson(pitchData, pitchData['id']?.toString() ?? ''),
          code: e['code']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      return [];
    }
  }

// 5) Kullanıcının saha için kodu var mı kontrol etme
  Future<bool> hasMatchingAccessCode(String haliSahaId, BuildContext context) async {
    try {
      final result = await functions
          .httpsCallable('hasMatchingAccessCode')
          .call({'haliSahaId': haliSahaId});

      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['ok'] != true) {
        return false;
      }
      return data['data']?['hasAccess'] == true;
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      return false;
    }
  }

}
