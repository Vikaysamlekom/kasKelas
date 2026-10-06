import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/audit_log_model.dart';
import '../models/cash_type_model.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';
import '../repositories/audit_repo.dart';
import '../repositories/cash_type_repo.dart';
import '../repositories/pembayaran_repo.dart';
import '../repositories/pengeluaran_repo.dart';
import '../repositories/siswa_repo.dart';

/// Filter daftar pengeluaran (periode + kategori).
class ExpenseFilter {
  final int? year;
  final int? month;
  final int? categoryId;

  const ExpenseFilter({this.year, this.month, this.categoryId});
}

/// Filter riwayat transaksi gabungan.
/// `kategori`: positif = cash_type id (pemasukan), negatif = −category id
/// (pengeluaran). 0/null = semua.
class RiwayatFilter {
  final String jenis; // '' = semua, 'pemasukan', 'pengeluaran'
  final int? kategori;
  final String? search;

  const RiwayatFilter({this.jenis = '', this.kategori, this.search});
}

/// Provider state Fase 4: pengeluaran, riwayat transaksi, dan audit log.
class TransactionProvider extends ChangeNotifier {
  final ExpenseRepository expenseRepository;
  final PaymentRepository paymentRepository;
  final CashTypeRepository cashTypeRepository;
  final AuditLogRepository auditLogRepository;

  TransactionProvider({
    required this.expenseRepository,
    required this.paymentRepository,
    required this.cashTypeRepository,
    required this.auditLogRepository,
  });

  List<ExpenseModel> _expenses = <ExpenseModel>[];
  List<ExpenseCategoryModel> _categories = <ExpenseCategoryModel>[];
  List<CashTypeModel> _incomeCategories = <CashTypeModel>[];
  List<TransactionItem> _riwayat = <TransactionItem>[];
  List<AuditLogModel> _audit = <AuditLogModel>[];
  ExpenseFilter _expenseFilter = ExpenseFilter();
  RiwayatFilter _riwayatFilter = const RiwayatFilter();
  bool _isLoadingExpenses = false;
  bool _isLoadingRiwayat = false;
  bool _isLoadingAudit = false;
  String? _error;

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseCategoryModel> get categories => _categories;
  List<CashTypeModel> get incomeCategories => _incomeCategories;
  List<TransactionItem> get riwayat => _riwayat;
  List<AuditLogModel> get auditLogs => _audit;
  ExpenseFilter get expenseFilter => _expenseFilter;
  RiwayatFilter get riwayatFilter => _riwayatFilter;
  bool get isLoadingExpenses => _isLoadingExpenses;
  bool get isLoadingRiwayat => _isLoadingRiwayat;
  bool get isLoadingAudit => _isLoadingAudit;
  String? get error => _error;

  // ------------------------------------------------------------
  // PENGELUARAN
  // ------------------------------------------------------------

  Future<void> loadExpenses() async {
    _isLoadingExpenses = true;
    notifyListeners();
    try {
      _expenses = await expenseRepository.list(
        year: _expenseFilter.year,
        month: _expenseFilter.month,
        categoryId: _expenseFilter.categoryId,
      );
    } catch (e) {
      _error = 'Gagal memuat pengeluaran: $e';
    } finally {
      _isLoadingExpenses = false;
      notifyListeners();
    }
  }

  Future<void> applyExpenseFilter({
    int? year,
    int? month,
    int? categoryId,
  }) async {
    _expenseFilter = ExpenseFilter(
      year: year ?? _expenseFilter.year,
      month: month ?? _expenseFilter.month,
      categoryId: categoryId ?? _expenseFilter.categoryId,
    );
    if (year != null && year == 0) {
      _expenseFilter = ExpenseFilter(
        month: _expenseFilter.month,
        categoryId: _expenseFilter.categoryId,
      );
    }
    if (month != null && month == 0) {
      _expenseFilter = ExpenseFilter(
        year: _expenseFilter.year,
        categoryId: _expenseFilter.categoryId,
      );
    }
    if (categoryId != null && categoryId == 0) {
      _expenseFilter =
          ExpenseFilter(year: _expenseFilter.year, month: _expenseFilter.month);
    }
    await loadExpenses();
  }

  Future<void> loadCategories() async {
    _categories = await expenseRepository.listCategories();
    notifyListeners();
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    String? description,
    int? userId,
  }) async {
    final ExpenseCategoryModel saved = await expenseRepository.saveCategory(
      id: id,
      name: name,
      description: description,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: id == null ? 'tambah' : 'ubah',
      entityTable: 'expense_categories',
      entityId: saved.id,
      description: '${id == null ? 'Tambah' : 'Ubah'} kategori ${saved.name}',
    );
    await loadCategories();
  }

  Future<DeleteResult> deleteCategory(int id, {int? userId}) async {
    final DeleteResult result = await expenseRepository.deleteCategory(id);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'hapus',
      entityTable: 'expense_categories',
      entityId: id,
      description: result.isDeactivated
          ? 'Nonaktifkan kategori id=$id'
          : 'Hapus kategori id=$id',
    );
    await loadCategories();
    return result;
  }

  Future<void> addExpense({
    required int categoryId,
    required int amount,
    required String expenseDate,
    required String description,
    String? receiptNote,
    String? photoPath,
    int? userId,
  }) async {
    final ExpenseModel created = await expenseRepository.add(
      categoryId: categoryId,
      amount: amount,
      expenseDate: expenseDate,
      description: description,
      receiptNote: receiptNote,
      photoPath: photoPath,
      recordedBy: userId,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'keluar',
      entityTable: 'expenses',
      entityId: created.id,
      description: 'Pengeluaran ${created.expenseCode} ${created.description}',
    );
    await loadExpenses();
  }

  // ------------------------------------------------------------
  // RIWAYAT
  // ------------------------------------------------------------

  Future<void> loadRiwayat() async {
    _isLoadingRiwayat = true;
    notifyListeners();
    try {
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        expenseRepository.riwayat(),
        expenseRepository.listCategories(),
        cashTypeRepository.list(),
      ]);
      _riwayat = results[0] as List<TransactionItem>;
      _categories = results[1] as List<ExpenseCategoryModel>;
      _incomeCategories = results[2] as List<CashTypeModel>;
    } catch (e) {
      _error = 'Gagal memuat riwayat: $e';
    } finally {
      _isLoadingRiwayat = false;
      notifyListeners();
    }
  }

  /// Riwayat setelah filter jenis/kategori/search (dipanggil UI).
  List<TransactionItem> get filteredRiwayat {
    final String jenis = _riwayatFilter.jenis;
    final int? kategori = _riwayatFilter.kategori;
    final String? q = _riwayatFilter.search?.trim();

    return _riwayat.where((TransactionItem t) {
      if (jenis.isNotEmpty && t.type != jenis) return false;
      if (kategori != null) {
        if (t.isIncome) {
          if (kategori <= 0 || t.incomeCategoryId != kategori) return false;
        } else {
          if (kategori >= 0 || t.expenseCategoryId != -kategori) return false;
        }
      }
      if (q != null && q.isNotEmpty) {
        final String hay = '${t.code} ${t.title} ${t.subtitle ?? ''} '
            '${t.categoryName ?? ''}';
        if (!hay.toLowerCase().contains(q.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  /// Set filter riwayat lalu notify langsung (filter sisi UI).
  void applyRiwayatFilter({
    String? jenis,
    int? kategori,
    String? search,
  }) {
    _riwayatFilter = RiwayatFilter(
      jenis: jenis ?? _riwayatFilter.jenis,
      kategori: kategori ?? _riwayatFilter.kategori,
      search: search ?? _riwayatFilter.search,
    );
    notifyListeners();
  }

  void clearRiwayatFilter() {
    _riwayatFilter = const RiwayatFilter();
    notifyListeners();
  }

  Future<void> voidPayment(
    int paymentId, {
    required String reason,
    int? userId,
  }) async {
    await paymentRepository.voidPayment(paymentId, reason: reason);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'batal',
      entityTable: 'payments',
      entityId: paymentId,
      description: 'Batalkan pembayaran id=$paymentId — alasan: $reason',
    );
    await loadRiwayat();
    await loadExpenses();
  }

  Future<void> voidExpense(
    int expenseId, {
    required String reason,
    int? userId,
  }) async {
    await expenseRepository.voidExpense(expenseId, reason: reason);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'batal',
      entityTable: 'expenses',
      entityId: expenseId,
      description: 'Batalkan pengeluaran id=$expenseId — alasan: $reason',
    );
    await loadRiwayat();
    await loadExpenses();
  }

  // ------------------------------------------------------------
  // AUDIT LOG
  // ------------------------------------------------------------

  Future<void> loadAudit({String? search}) async {
    _isLoadingAudit = true;
    notifyListeners();
    try {
      _audit = await auditLogRepository.list(search: search);
    } catch (e) {
      _error = 'Gagal memuat audit log: $e';
    } finally {
      _isLoadingAudit = false;
      notifyListeners();
    }
  }
}