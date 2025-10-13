import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/firebase_functions_service.dart';

class StatsProvider extends ChangeNotifier {
  // Tek kullanıcı için sayılar
  int ownApprovedCount = 0;
  int ownCancelledCount = 0;
  int allApprovedCount = 0;
  int allCancelledCount = 0;

  // Çoklu kullanıcı için liste
  List<Map<String, dynamic>> allUserStats = [];

  bool isLoading = false;

  /// Tek kullanıcı istatistikleri
  Future<void> loadStats(Reservation reservation) async {
    try {
      final function = functions.httpsCallable('getUserStats');
      final result = await function.call({
        'userId': reservation.userId,
        'haliSahaId': reservation.haliSahaId,
      });

      final data = result.data;
      ownApprovedCount  = data['ownApprovedCount'];
      ownCancelledCount = data['ownCancelledCount'];
      allApprovedCount  = data['allApprovedCount'];
      allCancelledCount = data['allCancelledCount'];
      notifyListeners();
    } catch (e) {
      debugPrint("Hata oluştu: $e");
    }
  }

  /// Çoklu kullanıcı istatistikleri (saha bazlı)
  Future<void> loadAllUserStatsForField(String haliSahaId) async {
    isLoading = true;
    notifyListeners();

    try {
      final fn = functions.httpsCallable('getAllUserStatsForField');
      final res = await fn.call({'haliSahaId': haliSahaId});

      debugPrint("📢 getAllUserStatsForField raw result: ${res.data}");

      // Defansif parse
      final raw = res.data;
      if (raw is! List) {
        allUserStats = [];
      } else {
        allUserStats = raw.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          // null güvenliği / tip normalize
          m['name'] = (m['name'] ?? '').toString();
          m['email'] = (m['email'] ?? '').toString();
          m['phone'] = (m['phone'] ?? '').toString();
          m['ownApprovedCount']  = (m['ownApprovedCount'] ?? 0) as int;
          m['ownCancelledCount'] = (m['ownCancelledCount'] ?? 0) as int;
          return m;
        }).toList();

        // Örn: en sorunlu kullanıcılar üste (iptale göre azalan)
        allUserStats.sort((a, b) =>
            (b['ownCancelledCount'] as int).compareTo(a['ownCancelledCount'] as int));
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("⚠️ Functions hata: code=${e.code}, msg=${e.message}, details=${e.details}");
      allUserStats = [];
    } catch (e) {
      debugPrint("⚠️ Genel hata: $e");
      allUserStats = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

}
