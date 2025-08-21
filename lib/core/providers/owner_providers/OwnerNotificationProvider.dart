import 'dart:async';
import 'package:flutter/material.dart';
import 'package:toplansin/services/owner_notification_service.dart';

class OwnerNotificationProvider with ChangeNotifier {
  final Map<String, int> _counts = {};

  // Artık her sahaId için ayrı abonelik tutuyoruz
  final Map<String, StreamSubscription> _resSubs = {};
  final Map<String, StreamSubscription> _subSubs = {};

  int getNotificationCount(String key) => _counts[key] ?? 0;

  void _update(String key, int count) {
    _counts[key] = count;
    notifyListeners();
  }

  /// Rezervasyon dinleyicisini başlatır (aynı sahaId için önceki iptal edilir)
  void startReservationListener(String haliSahaId) {
    _resSubs[haliSahaId]?.cancel();
    _resSubs[haliSahaId] = listenToReservationRequests(
      haliSahaId: haliSahaId,
      onCountUpdated: (cnt) => _update("reservation_$haliSahaId", cnt),
    );
  }

  /// Abonelik dinleyicisini başlatır (aynı sahaId için önceki iptal edilir)
  void startSubscriptionListener(String haliSahaId) {
    _subSubs[haliSahaId]?.cancel();
    _subSubs[haliSahaId] = listenToSubscriptionRequests(
      haliSahaId: haliSahaId,
      onCountUpdated: (cnt) => _update("subscription_$haliSahaId", cnt),
    );
  }

  /// Tüm dinleyicileri durdurur
  void stopAllListeners() {
    for (var sub in _resSubs.values) {
      sub.cancel();
    }
    for (var sub in _subSubs.values) {
      sub.cancel();
    }
    _resSubs.clear();
    _subSubs.clear();
  }

  @override
  void dispose() {
    stopAllListeners();
    super.dispose();
  }
}
