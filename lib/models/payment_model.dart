/// Model pembayaran (payments).
class PaymentModel {
  final int? id;
  final String paymentCode;
  final int studentId;
  final int cashTypeId;
  final int amount;
  final int month;
  final int year;
  final String? periodStart;
  final String? periodEnd;
  final String paidDate;
  final String paymentMethod; // tunai / transfer / qris
  final String status; // lunas / pending / sebagian
  final String? note;
  final String? voidReason;
  final int? recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kolom tambahan hasil JOIN (tidak disimpan ke DB).
  final String? studentName;
  final String? studentNis;
  final String? cashTypeName;
  final String? cashTypeFrequency;
  final String? className;
  final String? officerName;

  const PaymentModel({
    this.id,
    required this.paymentCode,
    required this.studentId,
    required this.cashTypeId,
    this.amount = 0,
    required this.month,
    required this.year,
    this.periodStart,
    this.periodEnd,
    required this.paidDate,
    this.paymentMethod = 'tunai',
    this.status = 'lunas',
    this.note,
    this.voidReason,
    this.recordedBy,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
    this.studentNis,
    this.cashTypeName,
    this.cashTypeFrequency,
    this.className,
    this.officerName,
  });

  factory PaymentModel.fromMap(Map<String, Object?> map) {
    return PaymentModel(
      id: map['id'] as int?,
      paymentCode: map['payment_code'] as String,
      studentId: map['student_id'] as int,
      cashTypeId: map['cash_type_id'] as int,
      amount: map['amount'] as int? ?? 0,
      month: map['month'] as int,
      year: map['year'] as int,
      periodStart: map['period_start'] as String?,
      periodEnd: map['period_end'] as String?,
      paidDate: map['paid_date'] as String,
      paymentMethod: (map['payment_method'] as String?) ?? 'tunai',
      status: (map['status'] as String?) ?? 'lunas',
      note: map['note'] as String?,
      voidReason: map['void_reason'] as String?,
      recordedBy: map['recorded_by'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      studentName: map['student_name'] as String?,
      studentNis: map['student_nis'] as String?,
      cashTypeName: map['cash_type_name'] as String?,
      cashTypeFrequency: map['cash_type_frequency'] as String?,
      className: map['class_name'] as String?,
      officerName: map['officer_name'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'payment_code': paymentCode,
      'student_id': studentId,
      'cash_type_id': cashTypeId,
      'amount': amount,
      'month': month,
      'year': year,
      'period_start': periodStart,
      'period_end': periodEnd,
      'paid_date': paidDate,
      'payment_method': paymentMethod,
      'status': status,
      'note': note,
      'recorded_by': recordedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PaymentStatus {
  static const String lunas = 'lunas';
  static const String pending = 'pending';
  static const String sebagian = 'sebagian';
  static const String belum = 'belum';
  static const String batal = 'batal';

  /// Label Indonesia: lunas → Lunas, dst.
  static String label(String status) {
    switch (status.toLowerCase()) {
      case lunas:
        return 'Lunas';
      case sebagian:
        return 'Sebagian';
      case belum:
        return 'Belum Bayar';
      case pending:
        return 'Pending';
      case batal:
        return 'Batal';
      default:
        return status;
    }
  }
}

class PaymentMethod {
  static const String tunai = 'tunai';
  static const String transfer = 'transfer';
  static const String qris = 'qris';
}
