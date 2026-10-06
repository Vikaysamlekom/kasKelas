import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/student_model.dart';
import '../repositories/kelas_repo.dart';
import '../repositories/siswa_repo.dart';
import '../services/csv_service.dart';

/// Status/arah hasil import CSV untuk ditampilkan ke UI.
class StudentsProvider extends ChangeNotifier {
  final StudentRepository studentRepository;
  final ClassRepository classRepository;

  StudentsProvider({
    required this.studentRepository,
    required this.classRepository,
  });

  List<StudentModel> _students = <StudentModel>[];
  StudentFilter _filter = const StudentFilter();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  String? _error;

  List<StudentModel> get students => _students;
  StudentFilter get filter => _filter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  String? get error => _error;

  /// Muat halaman pertama (reset daftar).
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _total = await studentRepository.countFiltered(_filter);
      _students = await studentRepository.list(
        _filter,
        limit: StudentRepository.pageSize,
      );
      _hasMore = _students.length < _total;
    } catch (e) {
      _error = 'Gagal memuat data siswa: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Muat halaman berikutnya (lazy loading saat scroll mendekati bawah).
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final List<StudentModel> next = await studentRepository.list(
        _filter,
        limit: StudentRepository.pageSize,
        offset: _students.length,
      );
      _students = <StudentModel>[..._students, ...next];
      _hasMore = next.length >= StudentRepository.pageSize &&
          _students.length < _total;
    } catch (e) {
      _error = 'Gagal memuat data siswa: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> applyFilter({
    String? search,
    int? classId,
    int? majorId,
    String? status,
  }) async {
    _filter = StudentFilter(
      search: search ?? _filter.search,
      classId: classId ?? _filter.classId,
      majorId: majorId ?? _filter.majorId,
      status: status ?? _filter.status,
    );
    // '' digunakan untuk "semua"
    if (search != null && search.isEmpty) {
      _filter = _filter.copyWith(search: '');
    }
    if (classId != null && classId == 0) {
      _filter = _filter.copyWith(classId: () => null);
    }
    if (majorId != null && majorId == 0) {
      _filter = _filter.copyWith(majorId: () => null);
    }
    if (status != null && status.isEmpty) {
      _filter = _filter.copyWith(status: () => null);
    }
    await load();
  }

  Future<StudentModel?> addStudent(Map<String, Object?> data, {int? userId}) async {
    final StudentModel created = await studentRepository.insert(
      _toModel(data, id: null),
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'tambah',
      entityTable: 'students',
      entityId: created.id,
      description: 'Tambah siswa ${created.name} (${created.nis})',
    );
    await load();
    return created;
  }

  Future<StudentModel?> updateStudent(int id, Map<String, Object?> data, {int? userId}) async {
    final StudentModel updated = await studentRepository.update(
      _toModel(data, id: id),
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'ubah',
      entityTable: 'students',
      entityId: id,
      description: 'Ubah data siswa ${updated.name} (${updated.nis})',
    );
    await load();
    return updated;
  }

  /// True bila berhasil dihapus; false bila diblokir (punya transaksi).
  Future<bool> deleteStudent(int id, {int? userId}) async {
    final bool removed = await studentRepository.delete(id);
    if (removed) {
      await DBHelper.instance.logAudit(
        userId: userId,
        action: 'hapus',
        entityTable: 'students',
        entityId: id,
        description: 'Hapus permanen data siswa id=$id',
      );
      await load();
    }
    return removed;
  }

  Future<StudentModel?> changeStatus(int id, String status, {int? userId}) async {
    final StudentModel updated = await studentRepository.changeStatus(id, status);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'ubah_status',
      entityTable: 'students',
      entityId: id,
      description: 'Ubah status siswa menjadi $status (${updated.name})',
    );
    await load();
    return updated;
  }

  /// Import siswa dari CSV yang dipilih pengguna. Mengembalikan hasil import.
  Future<CsvImportResult> importFromCsv({int? userId}) async {
    final String? content = await CsvStudentService.pickCsvContent();
    if (content == null) {
      return CsvImportResult(rows: const <CsvRowResult>[], successCount: 0, errorCount: 0);
    }

    final Map<String, int> classByName = <String, int>{};
    final List<ClassWithMeta> classes = await classRepository.listClasses(
      onlyActive: true,
    );
    for (final ClassWithMeta c in classes) {
      classByName[c.kelas.name] = c.kelas.id!;
    }

    final List<StudentModel> existing = await studentRepository.list(
      const StudentFilter(),
    );

    // Cek duplikat NIS di DB (dan antar baris CSV).
    final Set<String> existingNis = existing.map((StudentModel s) => s.nis).toSet();

    final CsvImportResult result = CsvStudentService.parse(
      content,
      classByName: classByName,
      existingNis: existingNis,
    );

    if (result.successCount > 0) {
      final String now = DateTime.now().toIso8601String();
      await DBHelper.instance.transaction((txn) async {
        for (final CsvRowResult row in result.rows) {
          if (row.error != null) continue;
          await txn.insert(
            'students',
            <String, Object?>{
              ...row.payload,
              'join_date': now.substring(0, 10),
              'is_active': 1,
              'created_at': now,
              'updated_at': now,
            },
          );
        }
      });
      await DBHelper.instance.logAudit(
        userId: userId,
        action: 'impor_csv',
        entityTable: 'students',
        description: 'Import ${result.successCount} siswa dari CSV (${result.errorCount} gagal)',
      );
      await load();
    }

    return result;
  }

  /// Jumlah transaksi pembayaran milik siswa.
  Future<int> paymentCount(int id) => studentRepository.paymentCount(id);

  /// Ambil satu siswa langsung dari database (tidak bergantung pada halaman
  /// yang sedang dimuat, penting setelah lazy loading).
  Future<StudentModel?> studentById(int id) =>
      studentRepository.getById(id);

  /// Export CSV → path file sementara yang sudah ditulis.
  /// Mengambil seluruh data yang cocok filter (bukan hanya halaman yang
  /// sudah dimuat di layar).
  Future<String> exportToCsv() async {
    final List<StudentModel> all = await studentRepository.list(_filter);
    return CsvStudentService.writeExportFile(all);
  }

  StudentModel _toModel(Map<String, Object?> data, {int? id}) {
    final DateTime now = DateTime.now();
    return StudentModel(
      id: id,
      nis: data['nis'] as String,
      nisn: data['nisn'] as String?,
      name: data['name'] as String,
      gender: data['gender'] as String? ?? 'L',
      classId: data['class_id'] as int?,
      majorId: data['major_id'] as int?,
      parentName: data['parent_name'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      status: data['status'] as String? ?? 'aktif',
      joinDate: data['join_date'] as String?,
      isActive: (data['status'] as String? ?? 'aktif') == 'aktif',
      createdAt: now,
      updatedAt: now,
    );
  }
}