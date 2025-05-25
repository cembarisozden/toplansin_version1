import 'package:flutter/cupertino.dart';

class OwnerNotificationProvider with ChangeNotifier {
  // Artık sadece halı saha ID değil, rezervasyon/abonelik ayrımı içeren key kullanılacak
  final Map<String, int> _notificationCounts = {};

  // Güncel: Key artık "subscription_abc123" veya "reservation_abc123" gibi olabilir
  int getNotificationCount(String key) {
    return _notificationCounts[key] ?? 0;
  }

  void setNotificationCount(String key, int count) {
    _notificationCounts[key] = count;
    notifyListeners();
  }

  void clearNotificationCount(String key) {
    _notificationCounts[key] = 0;
    notifyListeners();
  }
}
