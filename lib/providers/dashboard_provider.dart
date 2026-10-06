import 'package:flutter/material.dart';

import '../repositories/dashboard_repository.dart';

/// Provider data Dashboard: saldo, statistik, dan progres per kelas.
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository repository;

  DashboardProvider({required this.repository});

  DashboardSummary? _summary;
  List<ClassProgress> _classProgress = <ClassProgress>[];
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedYear;
  int? _selectedMonth;

  DashboardSummary? get summary => _summary;
  List<ClassProgress> get classProgress => _classProgress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int? get selectedYear => _selectedYear;
  int? get selectedMonth => _selectedMonth;

  /// Muat ulang seluruh data dashboard.
  Future<void> load({int? year, int? month}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedYear = year;
      _selectedMonth = month;

      // Jalankan dua query paralel untuk performa.
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        repository.getSummary(),
        repository.getClassProgress(year: year, month: month),
      ]);

      _summary = results[0] as DashboardSummary;
      _classProgress = (results[1] as List<ClassProgress>);
    } catch (e) {
      _errorMessage = 'Tidak dapat memuat data dashboard: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atur bulan pada filter (jika dipakai di dashboard). null = bulan berjalan.
  void selectPeriod({int? year, int? month}) {
    load(year: year, month: month);
  }
}
