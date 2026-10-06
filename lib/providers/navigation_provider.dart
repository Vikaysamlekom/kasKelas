import 'package:flutter/material.dart';

/// Indeks tab pada bottom navigation utama.
class NavigationIndex {
  static const int dashboard = 0;
  static const int students = 1;
  static const int payments = 2;
  static const int more = 3;
}

/// Provider untuk tracking tab aktif pada bottom navigation.
class NavigationProvider extends ChangeNotifier {
  int _index = NavigationIndex.dashboard;

  int get index => _index;

  void setIndex(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}