/// Model kelas (classes) siswa.
class ClassModel {
  final int? id;
  final String name;
  final int level;
  final int? majorId;
  final String academicYear;
  final String? homeroomTeacher;
  final bool isActive;
  final DateTime createdAt;

  const ClassModel({
    this.id,
    required this.name,
    required this.level,
    this.majorId,
    required this.academicYear,
    this.homeroomTeacher,
    this.isActive = true,
    required this.createdAt,
  });

  factory ClassModel.fromMap(Map<String, Object?> map) {
    return ClassModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: map['level'] as int,
      majorId: map['major_id'] as int?,
      academicYear: map['academic_year'] as String,
      homeroomTeacher: map['homeroom_teacher'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name,
      'level': level,
      'major_id': majorId,
      'academic_year': academicYear,
      'homeroom_teacher': homeroomTeacher,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}