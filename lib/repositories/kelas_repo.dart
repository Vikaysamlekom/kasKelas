import '../database/db_helper.dart';
import '../models/class_model.dart';
import '../models/major_model.dart';
import 'siswa_repo.dart';

/// Kelas dengan informasi tambahan untuk UI.
class ClassWithMeta {
  final ClassModel kelas;
  final String? majorName;
  final int studentCount;

  const ClassWithMeta({
    required this.kelas,
    this.majorName,
    this.studentCount = 0,
  });
}

/// Jurusan dengan informasi tambahan untuk UI.
class MajorWithMeta {
  final MajorModel major;
  final int classCount;

  const MajorWithMeta({required this.major, this.classCount = 0});
}

/// Repository data kelas (classes) & jurusan (majors).
class ClassRepository {
  final DBHelper _db = DBHelper.instance;

  // ------------------------------------------------------------
  // JURUSAN (MAJORS)
  // ------------------------------------------------------------

  Future<List<MajorWithMeta>> listMajors({bool onlyActive = false}) async {
    final String where = onlyActive ? 'WHERE m.is_active = 1' : '';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT m.*, (SELECT COUNT(*) FROM classes c
                   WHERE c.major_id = m.id) AS class_count
      FROM majors m
      $where
      ORDER BY m.name ASC
      ''',
    );
    return rows
        .map((Map<String, Object?> r) {
          final MajorModel m = MajorModel.fromMap(r);
          return MajorWithMeta(
            major: m,
            classCount: (r['class_count'] as int?) ?? 0,
          );
        })
        .toList();
  }

  Future<MajorModel> saveMajor({int? id, required String name, required String code, String? description}) async {
    final String now = DateTime.now().toIso8601String();
    if (id == null) {
      final int newId = await _db.insert(DBHelper.tblMajors, <String, Object?>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'description': description,
        'is_active': 1,
        'created_at': now,
      });
      return MajorModel(
        id: newId,
        name: name.trim(),
        code: code.trim().toUpperCase(),
        description: description,
        createdAt: DateTime.now(),
      );
    }
    await _db.update(
      DBHelper.tblMajors,
      <String, Object?>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'description': description,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return MajorModel(
      id: id,
      name: name.trim(),
      code: code.trim().toUpperCase(),
      description: description,
      createdAt: DateTime.now(),
    );
  }

  /// Hapus jurusan. Jika masih dipakai kelas → nonaktifkan (soft delete).
  Future<DeleteResult> deleteMajor(int id) async {
    final int classCount = await _db.count(
      DBHelper.tblClasses,
      where: 'major_id = ? AND is_active = 1',
      whereArgs: <Object?>[id],
    );
    if (classCount > 0) {
      final int updated = await _db.update(
        DBHelper.tblMajors,
        <String, Object?>{'is_active': 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return DeleteResult.fromUpdate(updated);
    }
    await _db.delete(DBHelper.tblMajors, where: 'id = ?', whereArgs: <Object?>[id]);
    return const DeleteResult.deleted();
  }

  // ------------------------------------------------------------
  // KELAS (CLASSES)
  // ------------------------------------------------------------

  Future<List<ClassWithMeta>> listClasses({bool onlyActive = false}) async {
    final String where = onlyActive ? 'WHERE c.is_active = 1' : '';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT c.*, m.name AS major_name,
             (SELECT COUNT(*) FROM students s
              WHERE s.class_id = c.id AND s.status = 'aktif'
                AND s.is_active = 1) AS student_count
      FROM classes c
      LEFT JOIN majors m ON m.id = c.major_id
      $where
      ORDER BY c.level ASC, c.name ASC
      ''',
    );
    return rows
        .map((Map<String, Object?> r) {
          final ClassModel c = ClassModel.fromMap(r);
          return ClassWithMeta(
            kelas: c,
            majorName: r['major_name'] as String?,
            studentCount: (r['student_count'] as int?) ?? 0,
          );
        })
        .toList();
  }

  Future<ClassWithMeta> saveClass({
    int? id,
    required String name,
    required int level,
    int? majorId,
    String? homeroomTeacher,
    required String academicYear,
  }) async {
    if (id == null) {
      final ClassModel newKelas = ClassModel(
        name: name.trim(),
        level: level,
        majorId: majorId,
        academicYear: academicYear,
        homeroomTeacher: homeroomTeacher,
        createdAt: DateTime.now(),
      );
      final int newId = await _db.insert(DBHelper.tblClasses, newKelas.toMap());
      return ClassWithMeta(
        kelas: ClassModel(
          id: newId,
          name: newKelas.name,
          level: newKelas.level,
          majorId: newKelas.majorId,
          academicYear: newKelas.academicYear,
          homeroomTeacher: newKelas.homeroomTeacher,
          createdAt: newKelas.createdAt,
        ),
        majorName: null,
      );
    }
    await _db.update(
      DBHelper.tblClasses,
      <String, Object?>{
        'name': name.trim(),
        'level': level,
        'major_id': majorId,
        'homeroom_teacher': homeroomTeacher,
        'academic_year': academicYear,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    final List<ClassWithMeta> all = await listClasses();
    return all.firstWhere((ClassWithMeta c) => c.kelas.id == id);
  }

  /// Hapus kelas. Jika masih ada siswa aktif → nonaktifkan (soft delete).
  Future<DeleteResult> deleteClass(int id) async {
    final int studentCount = await _db.count(
      DBHelper.tblStudents,
      where: 'class_id = ? AND is_active = 1',
      whereArgs: <Object?>[id],
    );
    if (studentCount > 0) {
      final int updated = await _db.update(
        DBHelper.tblClasses,
        <String, Object?>{'is_active': 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return DeleteResult.fromUpdate(updated);
    }
    await _db.delete(DBHelper.tblClasses, where: 'id = ?', whereArgs: <Object?>[id]);
    return const DeleteResult.deleted();
  }

  /// Kode jurusan dipakai? (cek duplikat)
  Future<bool> majorCodeExists(String code, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM majors WHERE code = ? AND id != ?',
      <Object?>[code.trim().toUpperCase(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }

  /// Nama kelas dipakai? (cek duplikat)
  Future<bool> classNameExists(String name, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM classes WHERE name = ? AND id != ?',
      <Object?>[name.trim(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }
}