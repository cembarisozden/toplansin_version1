import 'package:flutter/cupertino.dart';

class UserNotificationProvider with ChangeNotifier {
  int _reservationCount = 0;
  int _subscriptionCount = 0;

  int get reservationCount => _reservationCount;
  int get subscriptionCount => _subscriptionCount;

  int get totalCount => _reservationCount + _subscriptionCount;

  void setReservationCount(int count) {
    _reservationCount = count;
    notifyListeners();
  }

  void setSubscriptionCount(int count) {
    _subscriptionCount = count;
    notifyListeners();
  }

  void clearAll() {
    _reservationCount = 0;
    _subscriptionCount = 0;
    notifyListeners();
  }
}
