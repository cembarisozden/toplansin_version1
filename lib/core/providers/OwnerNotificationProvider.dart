import 'package:flutter/material.dart';

class OwnerNotificationProvider with ChangeNotifier {
  // Her Halı Saha için bildirim sayısını tutan map
  Map<String, int> _notificationCounts = {};

  // Bildirim sayısını almak için getter
  int getNotificationCount(String haliSahaId) {
    return _notificationCounts[haliSahaId] ?? 0;
  }


  // Bildirim sayısını ayarlamak için metod
  void setNotificationCount(String haliSahaId, int count) {
    _notificationCounts[haliSahaId] = count;
    notifyListeners();
  }
}
