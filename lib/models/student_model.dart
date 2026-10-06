/// Model siswa (students).
class StudentModel {
  final int? id;
  final String nis;
  final String? nisn;
  final String name;
  final String gender; // L / P
  final int? classId;
  final int? majorId;
  final String? parentName;
  final String? phone;
  final String? address;
  final String status; // aktif / cuti / lulus
  final String? joinDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kolom tambahan hasil JOIN (tidak disimpan ke DB).
  final String? className;
  final String? majorName;

  const StudentModel({
    this.id,
    required this.nis,
    this.nisn,
    required this.name,
    this.gender = 'L',
    this.classId,
    this.majorId,
    this.parentName,
    this.phone,
    this.address,
    this.status = 'aktif',
    this.joinDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.majorName,
  });

  factory StudentModel.fromMap(Map<String, Object?> map) {
    return StudentModel(
      id: map['id'] as int?,
      nis: map['nis'] as String,
      nisn: map['nisn'] as String?,
      name: map['name'] as String,
      gender: (map['gender'] as String?) ?? 'L',
      classId: map['class_id'] as int?,
      majorId: map['major_id'] as int?,
      parentName: map['parent_name'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      status: (map['status'] as String?) ?? 'aktif',
      joinDate: map['join_date'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      className: map['class_name'] as String?,
      majorName: map['major_name'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'nis': nis,
      'nisn': nisn,
      'name': name,
      'gender': gender,
      'class_id': classId,
      'major_id': majorId,
      'parent_name': parentName,
      'phone': phone,
      'address': address,
      'status': status,
      'join_date': joinDate,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StudentModel copyWith({int? classId, int? majorId}) {
    return StudentModel(
      id: id,
      nis: nis,
      nisn: nisn,
      name: name,
      gender: gender,
      classId: classId ?? this.classId,
      majorId: majorId ?? this.majorId,
      parentName: parentName,
      phone: phone,
      address: address,
      status: status,
      joinDate: joinDate,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      className: className,
      majorName: majorName,
    );
  }
}

/// Jenis kelamin.
class Gender {
  static const String lakiLaki = 'L';
  static const String perempuan = 'P';

  static String label(String gender) => gender == perempuan ? 'Perempuan' : 'Laki-laki';
}