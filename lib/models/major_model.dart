/// Model jurusan (majors) di sekolah.
class MajorModel {
  final int? id;
  final String name;
  final String code;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const MajorModel({
    this.id,
    required this.name,
    required this.code,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory MajorModel.fromMap(Map<String, Object?> map) {
    return MajorModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
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
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}