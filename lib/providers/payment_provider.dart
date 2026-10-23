import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/cash_type_model.dart';
import '../models/payment_model.dart';
import '../models/student_model.dart';
import '../repositories/cash_type_repo.dart';
import '../repositories/kelas_repo.dart';
import '../repositories/pembayaran_repo.dart';
import '../repositories/siswa_repo.dart';

/// Filter daftar pembayaran (periode + kelas).
class PaymentFilter {
  final int? year;
  final int? month;
  final int? classId;

  const PaymentFilter({this.year, this.month, this.classId});
}

/// Filter tunggakan (periode + kelas/jurusan + jenis kas + status).
class TunggakanFilter {
  final int? year;
  final int? month;
  final int? classId;
  final int? majorId;
  /// Jenis kas aktif yang jadi dasar kewajiban. Wajib terisi agar
  /// kewajiban/tunggakan dihitung per jenis kas (bukan total sum).
  final int? cashTypeId;
  final String status; // '' = semua, 'belum', 'sebagian'

  const TunggakanFilter({
    this.year,
    this.month,
    this.classId,
    this.majorId,
    this.cashTypeId,
    this.status = '',
  });
}

/// Provider state untuk halaman pembayaran, form, tunggakan & bukti.
class PaymentProvider extends ChangeNotifier {
  final PaymentRepository paymentRepository;
  final ClassRepository classRepository;
  final StudentRepository studentRepository;
  final CashTypeRepository cashTypeRepository;

  PaymentProvider({
    required this.paymentRepository,
    required this.classRepository,
    required this.studentRepository,
    required this.cashTypeRepository,
  });

  List<PaymentModel> _payments = <PaymentModel>[];
  List<TunggakanItem> _tunggakan = <TunggakanItem>[];
  List<StudentModel> _students = <StudentModel>[];
  PaymentFilter _filter = PaymentFilter(
    year: DateTime.now().year,
    month: DateTime.now().month,
  );
  TunggakanFilter _tunggakanFilter = TunggakanFilter(
    year: DateTime.now().year,
    month: DateTime.now().month,
  );
  bool _isLoading = false;
  bool _isLoadingTunggakan = false;
  String? _error;

  List<PaymentModel> get payments => _payments;
  List<TunggakanItem> get tunggakan => _tunggakan;
  List<StudentModel> get students => _students;
  PaymentFilter get filter => _filter;
  TunggakanFilter get tunggakanFilter => _tunggakanFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingTunggakan => _isLoadingTunggakan;
  String? get error => _error;

  /// Total nominal dari daftar pembayaran yang sedang tampil.
  int get totalPenerimaan =>
      _payments.fold<int>(0, (int sum, PaymentModel p) => sum + p.amount);

  /// Total sisa tunggakan dari daftar yang sedang tampil.
  int get totalTunggakan => _tunggakan.fold<int>(
      0, (int sum, TunggakanItem t) => sum + (t.status == 'lunas' ? 0 : t.sisa));

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _payments = await paymentRepository.list(
        year: _filter.year,
        month: _filter.month,
        classId: _filter.classId,
      );
    } catch (e) {
      _error = 'Gagal memuat pembayaran: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilter({int? year, int? month, int? classId}) async {
    _filter = PaymentFilter(
      year: year ?? _filter.year,
      month: month ?? _filter.month,
      classId: classId ?? _filter.classId,
    );
    // 0 dipakai UI untuk "Semua".
    if (year != null && year == 0) {
      _filter = PaymentFilter(
        year: null,
        month: month ?? _filter.month,
        classId: classId ?? _filter.classId,
      );
    }
    if (month != null && month == 0) {
      _filter = PaymentFilter(year: _filter.year, month: null, classId: _filter.classId);
    }
    if (classId != null && classId == 0) {
      _filter = PaymentFilter(year: _filter.year, month: _filter.month, classId: null);
    }
    await load();
  }

  Future<void> loadTunggakan() async {
    _isLoadingTunggakan = true;
    notifyListeners();
    try {
      // Kewajiban mengacu pada jenis kas terpilih. Bila belum ada pilihan,
      // otomatis pakai jenis kas aktif pertama (urut nama).
      if (_tunggakanFilter.cashTypeId == null) {
        final List<CashTypeModel> aktif =
            await cashTypeRepository.list(onlyActive: true);
        _tunggakanFilter = TunggakanFilter(
          year: _tunggakanFilter.year,
          month: _tunggakanFilter.month,
          classId: _tunggakanFilter.classId,
          majorId: _tunggakanFilter.majorId,
          cashTypeId: aktif.isNotEmpty ? aktif.first.id : null,
          status: _tunggakanFilter.status,
        );
      }
      _tunggakan = await paymentRepository.listTunggakan(
        month: _tunggakanFilter.month,
        year: _tunggakanFilter.year,
        classId: _tunggakanFilter.classId,
        majorId: _tunggakanFilter.majorId,
        cashTypeId: _tunggakanFilter.cashTypeId,
      );
    } catch (e) {
      _error = 'Gagal memuat tunggakan: $e';
    } finally {
      _isLoadingTunggakan = false;
      notifyListeners();
    }
  }

  Future<void> applyTunggakanFilter({
    int? year,
    int? month,
    int? classId,
    int? majorId,
    int? cashTypeId,
    String? status,
  }) async {
    // 0 dipakai UI untuk "Semua"; cashTypeId = 0 tidak valid sehingga
    // dipetakan ke null agar default otomatis (kas aktif pertama) kembali.
    final int efektifKas = cashTypeId ?? _tunggakanFilter.cashTypeId ?? 0;
    _tunggakanFilter = TunggakanFilter(
      year: year ?? _tunggakanFilter.year,
      month: month ?? _tunggakanFilter.month,
      classId: classId ?? _tunggakanFilter.classId,
      majorId: majorId ?? _tunggakanFilter.majorId,
      cashTypeId: efektifKas <= 0 ? null : efektifKas,
      status: status ?? _tunggakanFilter.status,
    );
    // 0 dipakai UI untuk "Semua".
    if (year != null && year == 0) {
      _tunggakanFilter = TunggakanFilter(month: _tunggakanFilter.month, classId: _tunggakanFilter.classId, majorId: _tunggakanFilter.majorId, cashTypeId: _tunggakanFilter.cashTypeId, status: _tunggakanFilter.status);
    }
    if (month != null && month == 0) {
      _tunggakanFilter = TunggakanFilter(year: _tunggakanFilter.year, classId: _tunggakanFilter.classId, majorId: _tunggakanFilter.majorId, cashTypeId: _tunggakanFilter.cashTypeId, status: _tunggakanFilter.status);
    }
    if (classId != null && classId == 0) {
      _tunggakanFilter = TunggakanFilter(year: _tunggakanFilter.year, month: _tunggakanFilter.month, majorId: _tunggakanFilter.majorId, cashTypeId: _tunggakanFilter.cashTypeId, status: _tunggakanFilter.status);
    }
    if (majorId != null && majorId == 0) {
      _tunggakanFilter = TunggakanFilter(year: _tunggakanFilter.year, month: _tunggakanFilter.month, classId: _tunggakanFilter.classId, cashTypeId: _tunggakanFilter.cashTypeId, status: _tunggakanFilter.status);
    }
    await loadTunggakan();
  }

  /// Muat daftar siswa aktif (data master untuk dropdown form).
  Future<void> loadActiveStudents() async {
    if (_students.isNotEmpty) return;
    final List<StudentModel> all =
        await studentRepository.list(const StudentFilter());
    _students = all
        .where((StudentModel s) => s.isActive && s.status == 'aktif')
        .toList();
    notifyListeners();
  }

  Future<PaymentModel> addPayment({
    required int studentId,
    required int cashTypeId,
    required int amount,
    required int month,
    required int year,
    required String paidDate,
    String paymentMethod = 'tunai',
    String? note,
    int? userId,
  }) async {
    final PaymentModel created = await paymentRepository.add(
      studentId: studentId,
      cashTypeId: cashTypeId,
      amount: amount,
      month: month,
      year: year,
      paidDate: paidDate,
      paymentMethod: paymentMethod,
      note: note,
      recordedBy: userId,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'bayar',
      entityTable: 'payments',
      entityId: created.id,
      description: 'Pembayaran ${created.paymentCode} '
          '${created.studentName ?? 'siswa id=${created.studentId}'}',
    );
    await load();
    return created;
  }

  Future<void> deletePayment(int id, {int? userId}) async {
    await paymentRepository.delete(id);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'hapus',
      entityTable: 'payments',
      entityId: id,
      description: 'Hapus transaksi pembayaran id=$id',
    );
    await load();
  }

  Future<PaymentModel?> paymentById(int id) => paymentRepository.getById(id);

  /// Status pembayaran siswa pada periode terpilih untuk jenis kas
  /// terpilih. Kewajiban = nominal jenis kas tersebut (bukan sum semua kas).
  Future<PeriodStatus> monthlyStatus(
    int studentId,
    int month,
    int year, {
    required int cashTypeId,
  }) {
    return paymentRepository.monthlyStatus(
      studentId,
      month,
      year,
      cashTypeId: cashTypeId,
    );
  }

  Future<int> kasPerBulan() => paymentRepository.kasPerBulan();
}