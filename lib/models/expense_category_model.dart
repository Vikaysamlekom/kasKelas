/// Model kategori pengeluaran (expense_categories).
class ExpenseCategoryModel {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategoryModel({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory ExpenseCategoryModel.fromMap(Map<String, Object?> map) {
    return ExpenseCategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}