import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/acces_code.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
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
      final col = _db
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .collection('accessCodes');

      final existing = await col.where('isActive', isEqualTo: true).get();
      final newDocRef = col.doc();
      final batch = _db.batch();

      for (var doc in existing.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(
          newDocRef,
          AccessCode(
            id: newDocRef.id,
            code: newCode,
            createdAt: TimeService.now(),
            createdBy: ownerUid,
            isActive: true,
          ).toJson());

      await batch.commit();
      await loadActiveCode(context, haliSahaId);
      AppSnackBar.success(context, 'Yeni erişim kodu oluşturuldu.');
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
    notifyListeners();
  }

  Future<void> activateCodeAgain({
    required BuildContext context,
    required String haliSahaId,
    required String codeId,
  }) async {
    try {
      final col = _db
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .collection('accessCodes');

      // 1) Mevcut aktif kodları çek
      final activeSnap = await col.where('isActive', isEqualTo: true).get();

      // 2) Batch işlemi başlat
      final batch = _db.batch();

      // 3) Eski aktif kodları pasifleştir
      for (var doc in activeSnap.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 4) Seçilen kodu aktifleştir
      final selectedRef = col.doc(codeId);
      batch.update(selectedRef, {
        'isActive': true,
        'deactivatedAt': FieldValue.delete(),
      });

      // 5) Commit ve yeniden yükleme
      await batch.commit();
      await loadActiveCode(context, haliSahaId);
      await loadInactiveCodes(context, haliSahaId);

      AppSnackBar.success(context, 'Kod başarıyla yeniden aktifleştirildi.');
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
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




  Future<HaliSaha?> findPitchByCode(
    BuildContext context,
    String code,
  ) async {
    try {
      print('[DEBUG] findPitchByCode code: "$code" (${code.runtimeType})');
      // accessCodes koleksiyonlar üzerinde collectionGroup ile arama
      final snap = await _db
          .collectionGroup('accessCodes')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        AppSnackBar.error(context, 'Geçerli bir kod bulunamadı.');
        return null;
      }

      // Kod belgesi referansından sahaId'yi çıkar
      final accDoc = snap.docs.first;
      final sahaRef = accDoc.reference.parent.parent!;
      final sahaSnap = await sahaRef.get();

      if (!sahaSnap.exists) {
        AppSnackBar.error(context, 'Halı saha bulunamadı.');
        return null;
      }

      // HaliSaha modelinin fromJson factory’si ile oluşturun
      return HaliSaha.fromJson(sahaSnap.data()!, sahaSnap.id);
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
      return null;
    }
  }

  /// 2) Kullanıcının `users/{uid}.fieldAccessCodes` listesine kodId ekler
  Future<void> addUserAccessCode(
      BuildContext context,
      String codeId,
      ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userRef = _db.collection('users').doc(uid);

      // 1️⃣ Kullanıcının mevcut kod listesini çek
      final userSnap = await userRef.get();
      final codes = List<String>.from(userSnap.data()?['fieldAccessCodes'] ?? []);

      // 2️⃣ Eğer kod zaten ekliyse bilgi ver, çık
      if (codes.contains(codeId)) {
        AppSnackBar.show(context, 'Bu kod zaten hesabınızda mevcut.');
        return;
      }

      // 3️⃣ Değilse arrayUnion ile ekle
      await userRef.update({
        'fieldAccessCodes': FieldValue.arrayUnion([codeId]),
      });
      AppSnackBar.success(context, 'Kod hesabınıza eklendi.');
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
  }


  /// 3) Kullanıcının `fieldAccessCodes` listesinden kodId çıkarır
  Future<void> removeUserAccessCode(
    BuildContext context,
    String codeId,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _db.collection('users').doc(uid).update({
        'fieldAccessCodes': FieldValue.arrayRemove([codeId]),
      });
      AppSnackBar.success(context, 'Kod hesabınızdan kaldırıldı.');
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
  }

  /// AccessCodeProvider içinde…

  /// Kullanıcının fieldAccessCodes listesinden hem kodu hem de saha bilgisini döner
  Future<List<UserCodeEntry>> loadUserCodes(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userSnap = await _db.collection('users').doc(uid).get();
      final codes = List<String>.from(userSnap.data()?['fieldAccessCodes'] ?? []);
      final List<UserCodeEntry> entries = [];

      for (var codeId in codes) {
        // 1) accessCodes doc’unu bul
        final accSnap = await _db
            .collectionGroup('accessCodes')
            .where('code', isEqualTo: codeId)       // <— burayı böyle değiştir
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();


        if (accSnap.docs.isEmpty) continue;
        final accDoc = accSnap.docs.first;

        // 2) parent hali_saha referansından saha dokümanını al
        final sahaRef = accDoc.reference.parent.parent!;
        final sahaSnap = await sahaRef.get();
        if (!sahaSnap.exists) continue;

        final saha = HaliSaha.fromJson(sahaSnap.data()!, sahaSnap.id);

        // 3) entry listesine ekle
        entries.add(UserCodeEntry(pitch: saha, code: AccessCode.fromDoc(accDoc).code));
      }

      return entries;
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      return [];
    }
  }

}
