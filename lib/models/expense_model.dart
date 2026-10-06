/// Model pengeluaran (expenses).
class ExpenseModel {
  final int? id;
  final String expenseCode;
  final int categoryId;
  final int amount;
  final String expenseDate;
  final String description; // keperluan
  final String? receiptNote; // keterangan
  final String? photoPath; // foto nota (opsional)
  final String status; // valid / batal
  final String? voidReason;
  final int? recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kolom tambahan hasil JOIN (tidak disimpan ke DB).
  final String? categoryName;
  final String? officerName;

  const ExpenseModel({
    this.id,
    required this.expenseCode,
    required this.categoryId,
    this.amount = 0,
    required this.expenseDate,
    required this.description,
    this.receiptNote,
    this.photoPath,
    this.status = 'valid',
    this.voidReason,
    this.recordedBy,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.officerName,
  });

  factory ExpenseModel.fromMap(Map<String, Object?> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      expenseCode: map['expense_code'] as String,
      categoryId: map['category_id'] as int,
      amount: map['amount'] as int? ?? 0,
      expenseDate: map['expense_date'] as String,
      description: map['description'] as String,
      receiptNote: map['receipt_note'] as String?,
      photoPath: map['photo_path'] as String?,
      status: (map['status'] as String?) ?? 'valid',
      voidReason: map['void_reason'] as String?,
      recordedBy: map['recorded_by'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      officerName: map['officer_name'] as String?,
    );
  }
}

/// Status pengeluaran.
class ExpenseStatus {
  static const String valid = 'valid';
  static const String batal = 'batal';

  static String label(String status) =>
      status == batal ? 'Batal' : 'Valid';
}