import '../database/db_helper.dart';
import '../models/student_model.dart';

/// Error saat NIS sudah dipakai siswa lain.
class DuplicateNisException implements Exception {
  final String nis;
  DuplicateNisException(this.nis);

  @override
  String toString() => 'NIS $nis sudah digunakan siswa lain.';
}

/// Hasil operasi delete/deaktivasi.
class DeleteResult {
  final bool isDeleted;
  final bool isDeactivated;

  const DeleteResult.deleted()
      : isDeleted = true,
        isDeactivated = false;

  const DeleteResult.deactivated()
      : isDeleted = false,
        isDeactivated = true;

  const DeleteResult.blocked()
      : isDeleted = false,
        isDeactivated = false;

  static DeleteResult fromUpdate(int updated) {
    return updated > 0 ? const DeleteResult.deactivated() : const DeleteResult.blocked();
  }
}

/// Filter pencarian siswa.
class StudentFilter {
  final String? search;
  final int? classId;
  final int? majorId;
  final String? status;

  const StudentFilter({this.search, this.classId, this.majorId, this.status});

  StudentFilter copyWith({
    String? search,
    int? Function()? classId,
    int? Function()? majorId,
    String? Function()? status,
  }) {
    return StudentFilter(
      search: search ?? this.search,
      classId: classId != null ? classId() : this.classId,
      majorId: majorId != null ? majorId() : this.majorId,
      status: status != null ? status() : this.status,
    );
  }
}

/// Repository data siswa (students) dengan JOIN kelas & jurusan.
class StudentRepository {
  final DBHelper _db = DBHelper.instance;

  /// Jumlah data per halaman untuk lazy loading.
  static const int pageSize = 50;

  /// Daftar siswa dengan filter (search, kelas, jurusan, status).
  /// [limit] & [offset] dipakai untuk lazy loading (null = tanpa paginasi).
  Future<List<StudentModel>> list(
    StudentFilter filter, {
    int? limit,
    int? offset,
  }) async {
    final List<String> where = <String>['1=1'];
    final List<Object?> args = <Object?>[];

    final String? search = filter.search?.trim();
    if (search != null && search.isNotEmpty) {
      where.add('(s.name LIKE ? OR s.nis LIKE ? OR s.nisn LIKE ?)');
      final String like = '%$search%';
      args.addAll(<Object?>[like, like, like]);
    }
    if (filter.classId != null) {
      where.add('s.class_id = ?');
      args.add(filter.classId);
    }
    if (filter.majorId != null) {
      where.add('COALESCE(s.major_id, c.major_id) = ?');
      args.add(filter.majorId);
    }
    if (filter.status != null && filter.status!.isNotEmpty) {
      where.add('s.status = ?');
      args.add(filter.status);
    }

    final String sql = '''
      SELECT s.*, c.name AS class_name, c.level AS class_level,
             m.name AS major_name
      FROM students s
      LEFT JOIN classes c ON c.id = s.class_id
      LEFT JOIN majors m ON m.id = COALESCE(s.major_id, c.major_id)
      WHERE ${where.join(' AND ')}
      ORDER BY c.level ASC, c.name ASC, s.name ASC
    ''';

    final String sqlPaged = limit != null
        ? '$sql LIMIT ? OFFSET ?'
        : sql;
    if (limit != null) {
      args.add(limit);
      args.add(offset ?? 0);
    }

    final List<Map<String, Object?>> rows =
        await _db.rawQuery(sqlPaged, args);
    return rows.map(StudentModel.fromMap).toList();
  }

  /// Total baris yang cocok filter (untuk menentukan masih ada halaman
  /// berikutnya atau tidak pada lazy loading).
  Future<int> countFiltered(StudentFilter filter) async {
    final List<String> where = <String>['1=1'];
    final List<Object?> args = <Object?>[];

    final String? search = filter.search?.trim();
    if (search != null && search.isNotEmpty) {
      where.add('(s.name LIKE ? OR s.nis LIKE ? OR s.nisn LIKE ?)');
      final String like = '%$search%';
      args.addAll(<Object?>[like, like, like]);
    }
    if (filter.classId != null) {
      where.add('s.class_id = ?');
      args.add(filter.classId);
    }
    if (filter.majorId != null) {
      where.add('COALESCE(s.major_id, c.major_id) = ?');
      args.add(filter.majorId);
    }
    if (filter.status != null && filter.status!.isNotEmpty) {
      where.add('s.status = ?');
      args.add(filter.status);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM students s
      LEFT JOIN classes c ON c.id = s.class_id
      WHERE ${where.join(' AND ')}
      ''',
      args,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<StudentModel?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT s.*, c.name AS class_name, c.level AS class_level,
             m.name AS major_name
      FROM students s
      LEFT JOIN classes c ON c.id = s.class_id
      LEFT JOIN majors m ON m.id = COALESCE(s.major_id, c.major_id)
      WHERE s.id = ?
      ''',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return StudentModel.fromMap(rows.first);
  }

  /// Cek apakah NIS sudah dipakai siswa lain.
  Future<bool> nisExists(String nis, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM students WHERE nis = ? AND id != ?',
      <Object?>[nis, excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }

  /// Simpan siswa baru. Melempar [DuplicateNisException] bila NIS ganda.
  Future<StudentModel> insert(StudentModel student) async {
    final String now = DateTime.now().toIso8601String();
    if (await nisExists(student.nis)) {
      throw DuplicateNisException(student.nis);
    }
    final int id = await _db.insert(
      DBHelper.tblStudents,
      StudentModel(
        nis: student.nis,
        nisn: student.nisn,
        name: student.name,
        gender: student.gender,
        classId: student.classId,
        majorId: student.majorId,
        parentName: student.parentName,
        phone: student.phone,
        address: student.address,
        status: student.status,
        joinDate: now.substring(0, 10),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toMap(),
    );
    final StudentModel? saved = await getById(id);
    if (saved == null) {
      throw StateError('Gagal menyimpan data siswa.');
    }
    return saved;
  }

  /// Perbarui siswa.
  Future<StudentModel> update(StudentModel student) async {
    if (student.id == null) {
      throw ArgumentError('ID siswa wajib ada untuk update.');
    }
    if (await nisExists(student.nis, excludeId: student.id)) {
      throw DuplicateNisException(student.nis);
    }
    await _db.update(
      DBHelper.tblStudents,
      <String, Object?>{
        'nis': student.nis,
        'nisn': student.nisn,
        'name': student.name,
        'gender': student.gender,
        'class_id': student.classId,
        'major_id': student.majorId,
        'parent_name': student.parentName,
        'phone': student.phone,
        'address': student.address,
        'status': student.status,
        'is_active': student.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[student.id],
    );
    final StudentModel? saved = await getById(student.id!);
    if (saved == null) {
      throw StateError('Gagal memperbarui data siswa.');
    }
    return saved;
  }

  /// Ubah status siswa (aktif/cuti/lulus). Siswa dengan transaksi
  /// pembayaran tidak bisa dihapus, hanya diganti statusnya.
  Future<StudentModel> changeStatus(int id, String status) async {
    await _db.update(
      DBHelper.tblStudents,
      <String, Object?>{
        'status': status,
        'is_active': status == 'aktif' ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    final StudentModel? saved = await getById(id);
    if (saved == null) {
      throw StateError('Siswa tidak ditemukan.');
    }
    return saved;
  }

  /// Hapus permanen siswa. Diblokir bila siswa punya riwayat pembayaran.
  /// Mengembalikan true bila terhapus.
  Future<bool> delete(int id) async {
    final int paymentCount = await _db.count(
      DBHelper.tblPayments,
      where: 'student_id = ?',
      whereArgs: <Object?>[id],
    );
    if (paymentCount > 0) {
      return false;
    }
    await _db.delete(
      DBHelper.tblStudents,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return true;
  }

  /// Jumlah transaksi pembayaran milik siswa.
  Future<int> paymentCount(int id) async {
    return _db.count(
      DBHelper.tblPayments,
      where: 'student_id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Tampilkan semua kelas aktif (untuk dropdown).
  Future<List<Map<String, Object?>>> activeClasses() async {
    return _db.query(
      DBHelper.tblClasses,
      where: 'is_active = 1',
      orderBy: 'level ASC, name ASC',
    );
  }
}