import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/major_model.dart';
import '../repositories/kelas_repo.dart';
import '../repositories/siswa_repo.dart';

/// Provider data kelas & jurusan.
class ClassesProvider extends ChangeNotifier {
  final ClassRepository classRepository;

  ClassesProvider({required this.classRepository});

  List<MajorWithMeta> _majors = <MajorWithMeta>[];
  List<ClassWithMeta> _classes = <ClassWithMeta>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  List<MajorWithMeta> get majors => _majors;
  List<ClassWithMeta> get classes => _classes;
  bool get isLoading => _isLoading;

  /// Sudah pernah menyelesaikan satu siklus [load].
  /// Dipakai agar layar tidak melakukan query ulang berulang-ulang saat
  /// daftar memang kosong (mis. belum ada kelas sama sekali).
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  MajorModel? majorById(int? id) {
    for (final MajorWithMeta m in _majors) {
      if (m.major.id == id) return m.major;
    }
    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        classRepository.listMajors(),
        classRepository.listClasses(),
      ]);
      _majors = results[0] as List<MajorWithMeta>;
      _classes = results[1] as List<ClassWithMeta>;
    } catch (e) {
      _error = 'Gagal memuat data kelas: $e';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Simpan jurusan. Mengembalikan id jurusan yang tersimpan.
  Future<int> saveMajor({
    int? id,
    required String name,
    required String code,
    String? description,
    int? userId,
  }) async {
    final MajorModel saved = await classRepository.saveMajor(
      id: id,
      name: name,
      code: code,
      description: description,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: id == null ? 'tambah' : 'ubah',
      entityTable: 'majors',
      entityId: saved.id,
      description: '${id == null ? 'Tambah' : 'Ubah'} jurusan ${saved.name}',
    );
    await load();
    return saved.id!;
  }

  /// Delete jurusan. Kembalikan DeleteResult (deleted / deactivated / blocked).
  Future<DeleteResult> deleteMajor(int id, {int? userId}) async {
    final DeleteResult result = await classRepository.deleteMajor(id);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'hapus',
      entityTable: 'majors',
      entityId: id,
      description: result.isDeactivated ? 'Nonaktifkan jurusan id=$id' : 'Hapus jurusan id=$id',
    );
    await load();
    return result;
  }

  /// Simpan kelas. Mengembalikan id kelas yang tersimpan.
  Future<int> saveClass({
    int? id,
    required String name,
    required int level,
    int? majorId,
    String? homeroomTeacher,
    String? academicYear,
    int? userId,
  }) async {
    final String year = academicYear ?? '2026/2027';
    final ClassWithMeta saved = await classRepository.saveClass(
      id: id,
      name: name,
      level: level,
      majorId: majorId,
      homeroomTeacher: homeroomTeacher,
      academicYear: year,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: id == null ? 'tambah' : 'ubah',
      entityTable: 'classes',
      entityId: saved.kelas.id,
      description: '${id == null ? 'Tambah' : 'Ubah'} kelas ${saved.kelas.name}',
    );
    await load();
    return saved.kelas.id!;
  }

  Future<DeleteResult> deleteClass(int id, {int? userId}) async {
    final DeleteResult result = await classRepository.deleteClass(id);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'hapus',
      entityTable: 'classes',
      entityId: id,
      description: result.isDeactivated ? 'Nonaktifkan kelas id=$id' : 'Hapus kelas id=$id',
    );
    await load();
    return result;
  }
}