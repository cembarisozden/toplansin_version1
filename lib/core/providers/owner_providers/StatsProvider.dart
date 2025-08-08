import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:toplansin/data/entitiy/reservation.dart';

class StatsProvider extends ChangeNotifier {
  int ownApprovedCount = 0;
  int ownCancelledCount = 0;
  int allApprovedCount = 0;
  int allCancelledCount = 0;

  Future<void> loadStats(Reservation reservation) async {
    try {
      final function = FirebaseFunctions.instance.httpsCallable('getUserStats');
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
}
