import '../database/db_helper.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';
import '../models/payment_model.dart';
import 'siswa_repo.dart';

/// Item gabungan pemasukan + pengeluaran untuk halaman riwayat transaksi.
class TransactionItem {
  final String type; // pemasukan / pengeluaran
  final String code;
  final int amount;
  final DateTime date;
  final String title;
  final String? subtitle;
  final String? categoryName;
  final String? note;
  final String? photoPath;
  final String status; // lunas/sebagian (pemasukan) | valid (pengeluaran) → 'batal'
  final String? voidReason;
  final int? paymentId;
  final int? expenseId;
  final String? officerName;
  final String? paymentMethod;
  final int? periodMonth;
  final int? periodYear;
  final String? studentNis;
  final String? className;
  final int? incomeCategoryId; // cash_type_id (pemasukan)
  final int? expenseCategoryId; // category_id (pengeluaran)

  const TransactionItem({
    required this.type,
    required this.code,
    required this.amount,
    required this.date,
    required this.title,
    this.subtitle,
    this.categoryName,
    this.note,
    this.photoPath,
    required this.status,
    this.voidReason,
    this.paymentId,
    this.expenseId,
    this.officerName,
    this.paymentMethod,
    this.periodMonth,
    this.periodYear,
    this.studentNis,
    this.className,
    this.incomeCategoryId,
    this.expenseCategoryId,
  });

  bool get isIncome => type == TransactionType.pemasukan;
  bool get isVoided => status == PaymentStatus.batal;
}

/// Jenis transaksi untuk riwayat & filter.
class TransactionType {
  static const String pemasukan = 'pemasukan';
  static const String pengeluaran = 'pengeluaran';
}

/// Repository data pengeluaran (expenses), daftar kategori pengeluaran,
/// dan riwayat transaksi gabungan (pemasukan + pengeluaran).
class ExpenseRepository {
  final DBHelper _db = DBHelper.instance;

  // ------------------------------------------------------------
  // KATEGORI PENGELUARAN
  // ------------------------------------------------------------

  Future<List<ExpenseCategoryModel>> listCategories(
      {bool onlyActive = false}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      DBHelper.tblExpenseCategories,
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(ExpenseCategoryModel.fromMap).toList();
  }

  Future<ExpenseCategoryModel> saveCategory({
    int? id,
    required String name,
    String? description,
  }) async {
    final String now = DateTime.now().toIso8601String();
    if (id == null) {
      final int newId = await _db.insert(
        DBHelper.tblExpenseCategories,
        <String, Object?>{
          'name': name.trim(),
          'description': description,
          'is_active': 1,
          'created_at': now,
        },
      );
      return ExpenseCategoryModel(
        id: newId,
        name: name.trim(),
        description: description,
        createdAt: DateTime.now(),
      );
    }
    await _db.update(
      DBHelper.tblExpenseCategories,
      <String, Object?>{'name': name.trim(), 'description': description},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return ExpenseCategoryModel(
      id: id,
      name: name.trim(),
      description: description,
      createdAt: DateTime.now(),
    );
  }

  /// Hapus kategori. Jika sudah dipakai pengeluaran → nonaktifkan.
  Future<DeleteResult> deleteCategory(int id) async {
    final int used = await _db.count(
      DBHelper.tblExpenses,
      where: 'category_id = ?',
      whereArgs: <Object?>[id],
    );
    if (used > 0) {
      final int updated = await _db.update(
        DBHelper.tblExpenseCategories,
        <String, Object?>{'is_active': 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return DeleteResult.fromUpdate(updated);
    }
    await _db.delete(
      DBHelper.tblExpenseCategories,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return const DeleteResult.deleted();
  }

  Future<bool> categoryNameExists(String name, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM ${DBHelper.tblExpenseCategories} '
      'WHERE name = ? AND id != ?',
      <Object?>[name.trim(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }

  // ------------------------------------------------------------
  // PENGELUARAN
  // ------------------------------------------------------------

  /// Kode pengeluaran otomatis → EXP-{tahun}{bulan2}-{urutan6}.
  Future<String> nextExpenseCode(int year, int month) async {
    final String mm = month.toString().padLeft(2, '0');
    final String prefix = 'EXP-$year$mm';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT expense_code FROM ${DBHelper.tblExpenses} '
      'WHERE expense_code LIKE ? ORDER BY expense_code DESC LIMIT 1',
      <Object?>['$prefix-%'],
    );
    if (rows.isEmpty) return '$prefix-000001';
    final String last = rows.first['expense_code'] as String;
    final int seq = int.tryParse(last.split('-').last) ?? 0;
    return '$prefix-${(seq + 1).toString().padLeft(6, '0')}';
  }

  Future<ExpenseModel> add({
    required int categoryId,
    required int amount,
    required String expenseDate,
    required String description,
    String? receiptNote,
    String? photoPath,
    int? recordedBy,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Nominal pengeluaran harus lebih dari 0.');
    }
    final DateTime date = DateTime.now();
    final String code =
        await nextExpenseCode(date.year, date.month);
    final String now = date.toIso8601String();
    final int id = await _db.insert(DBHelper.tblExpenses, <String, Object?>{
      'expense_code': code,
      'category_id': categoryId,
      'amount': amount,
      'expense_date': expenseDate,
      'description': description.trim(),
      'receipt_note': receiptNote,
      'photo_path': photoPath,
      'status': ExpenseStatus.valid,
      'recorded_by': recordedBy,
      'created_at': now,
      'updated_at': now,
    });
    final ExpenseModel? saved = await getById(id);
    if (saved == null) {
      throw StateError('Gagal menyimpan pengeluaran.');
    }
    return saved;
  }

  /// Daftar pengeluaran dengan filter periode & kategori.
  Future<List<ExpenseModel>> list({
    int? year,
    int? month,
    int? categoryId,
  }) async {
    final List<String> where = <String>['1=1'];
    final List<Object?> args = <Object?>[];
    if (year != null) {
      where.add("substr(e.expense_date, 1, 4) = ?");
      args.add(year.toString());
    }
    if (month != null) {
      where.add("substr(e.expense_date, 6, 2) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }
    if (categoryId != null) {
      where.add('e.category_id = ?');
      args.add(categoryId);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT e.*, c.name AS category_name, u.full_name AS officer_name
      FROM ${DBHelper.tblExpenses} e
      LEFT JOIN ${DBHelper.tblExpenseCategories} c ON c.id = e.category_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = e.recorded_by
      WHERE ${where.join(' AND ')}
      ORDER BY e.expense_date DESC, e.id DESC
      ''',
      args,
    );
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<ExpenseModel?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT e.*, c.name AS category_name, u.full_name AS officer_name
      FROM ${DBHelper.tblExpenses} e
      LEFT JOIN ${DBHelper.tblExpenseCategories} c ON c.id = e.category_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = e.recorded_by
      WHERE e.id = ?
      LIMIT 1
      ''',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return ExpenseModel.fromMap(rows.first);
  }

  /// Batalkan (void) pengeluaran → status batal + alasan wajib.
  Future<void> voidExpense(int id, {required String reason}) async {
    await _db.update(
      DBHelper.tblExpenses,
      <String, Object?>{
        'status': ExpenseStatus.batal,
        'void_reason': reason.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  // ------------------------------------------------------------
  // RIWAYAT GABUNGAN
  // ------------------------------------------------------------

  /// Semua transaksi (pemasukan + pengeluaran) urut tanggal terbaru.
  Future<List<TransactionItem>> riwayat() async {
    final List<TransactionItem> items = <TransactionItem>[];

    // PEMASUKAN (payments)
    final List<Map<String, Object?>> payments = await _db.rawQuery(
      '''
      SELECT p.*, s.name AS student_name, s.nis AS student_nis,
             c.name AS class_name, ct.name AS cash_type_name,
             u.full_name AS officer_name
      FROM ${DBHelper.tblPayments} p
      JOIN ${DBHelper.tblStudents} s ON s.id = p.student_id
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblCashTypes} ct ON ct.id = p.cash_type_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = p.recorded_by
      ''',
    );
    for (final Map<String, Object?> r in payments) {
      final DateTime? date = DateTime.tryParse(r['paid_date'] as String);
      items.add(
        TransactionItem(
          type: TransactionType.pemasukan,
          code: r['payment_code'] as String,
          amount: r['amount'] as int,
          date: date ?? DateTime.now(),
          title: (r['student_name'] as String?) ?? 'Siswa',
          subtitle: 'NIS ${r['student_nis'] ?? '-'} · ${r['class_name'] ?? '-'}',
          categoryName: r['cash_type_name'] as String?,
          note: r['note'] as String?,
          status: (r['status'] as String?) ?? PaymentStatus.lunas,
          voidReason: r['void_reason'] as String?,
          paymentId: r['id'] as int,
          officerName: r['officer_name'] as String?,
          paymentMethod: (r['payment_method'] as String?) ?? 'tunai',
          periodMonth: r['month'] as int?,
          periodYear: r['year'] as int?,
          studentNis: r['student_nis'] as String?,
          className: r['class_name'] as String?,
          incomeCategoryId: r['cash_type_id'] as int?,
        ),
      );
    }

    // PENGELUARAN (expenses)
    final List<Map<String, Object?>> expenses = await _db.rawQuery(
      '''
      SELECT e.*, c.name AS category_name, u.full_name AS officer_name
      FROM ${DBHelper.tblExpenses} e
      LEFT JOIN ${DBHelper.tblExpenseCategories} c ON c.id = e.category_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = e.recorded_by
      ''',
    );
    for (final Map<String, Object?> r in expenses) {
      final DateTime? date = DateTime.tryParse(r['expense_date'] as String);
      items.add(
        TransactionItem(
          type: TransactionType.pengeluaran,
          code: r['expense_code'] as String,
          amount: r['amount'] as int,
          date: date ?? DateTime.now(),
          title: (r['description'] as String?) ?? 'Pengeluaran',
          subtitle: r['category_name'] as String?,
          categoryName: r['category_name'] as String?,
          note: r['receipt_note'] as String?,
          photoPath: r['photo_path'] as String?,
          status: (r['status'] as String?) ?? ExpenseStatus.valid,
          voidReason: r['void_reason'] as String?,
          expenseId: r['id'] as int,
          officerName: r['officer_name'] as String?,
          expenseCategoryId: r['category_id'] as int?,
        ),
      );
    }

    items.sort((a, b) {
      final int byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.code.compareTo(a.code);
    });
    return items;
  }
}