// lib/core/providers/bottom_nav_provider.dart
import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int newIndex) {
    _index = newIndex;
    notifyListeners();
  }
}
