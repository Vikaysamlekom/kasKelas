/// Model jenis kas / iuran (cash_types).
class CashTypeModel {
  final int? id;
  final String name;
  final String code;
  final int amount;
  final String frequency; // bulanan / semester / tahunan / sekali
  final int dueDay;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const CashTypeModel({
    this.id,
    required this.name,
    required this.code,
    this.amount = 0,
    this.frequency = 'bulanan',
    this.dueDay = 10,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory CashTypeModel.fromMap(Map<String, Object?> map) {
    return CashTypeModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      amount: map['amount'] as int? ?? 0,
      frequency: (map['frequency'] as String?) ?? 'bulanan',
      dueDay: map['due_day'] as int? ?? 10,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name,
      'code': code,
      'amount': amount,
      'frequency': frequency,
      'due_day': dueDay,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PaymentFrequency {
  static const String bulanan = 'bulanan';
  static const String semester = 'semester';
  static const String tahunan = 'tahunan';
  static const String sekali = 'sekali';
}