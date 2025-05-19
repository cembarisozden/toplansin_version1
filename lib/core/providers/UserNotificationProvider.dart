import 'package:flutter/cupertino.dart';

class UserNotificationProvider with ChangeNotifier {
  int _count = 0;

  int get notificationCount => _count;

  void setCount(int count) {
    _count = count;
    notifyListeners();
  }

  void clearCount() {
    _count = 0;
    notifyListeners();
  }
}
