import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/student_model.dart';

/// Hasil parsing satu baris CSV.
class CsvRowResult {
  final int rowNumber;
  final String? nis;
  final String? name;
  final String? error;
  final Map<String, Object?> payload; // data siap insert (tanpa created_at)

  const CsvRowResult({
    required this.rowNumber,
    this.nis,
    this.name,
    this.error,
    this.payload = const <String, Object?>{},
  });
}

/// Ringkasan hasil import CSV.
class CsvImportResult {
  final List<CsvRowResult> rows;
  final int successCount;
  final int errorCount;

  const CsvImportResult({
    required this.rows,
    required this.successCount,
    required this.errorCount,
  });
}

/// Layanan import/export data siswa via CSV.
class CsvStudentService {
  static const List<String> headers = <String>[
    'NIS',
    'NISN',
    'Nama',
    'Jenis Kelamin',
    'Kelas',
    'No HP Wali',
    'Status',
  ];

  /// Bangun konten CSV dari daftar siswa (dengan BOM UTF-8 agar Excel aman).
  static String exportCsv(List<StudentModel> students) {
    final List<List<dynamic>> rows = <List<dynamic>>[headers];
    for (final StudentModel s in students) {
      rows.add(<dynamic>[
        s.nis,
        s.nisn ?? '',
        s.name,
        s.gender,
        s.className ?? '',
        s.phone ?? '',
        s.status,
      ]);
    }
    final String body = const ListToCsvConverter().convert(rows);
    return '\uFEFF$body';
  }

  /// Tulis file CSV di direktori sementara app & kembalikan path-nya.
  static Future<String> writeExportFile(List<StudentModel> students) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/kas_siswa_export.csv');
    await file.writeAsString(exportCsv(students), encoding: utf8);
    return file.path;
  }

  /// Pilih file CSV dari penyimpanan & kembalikan isi teksnya.
  static Future<String?> pickCsvContent() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
    );
    if (files.isEmpty) return null;

    final PlatformFile file = files.first;
    final List<int> bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Parse isi CSV menjadi [CsvImportResult].
  ///
  /// [classByName]: pemetaan nama kelas → id kelas (kelas aktif).
  /// [existingNis]: daftar NIS yang sudah ada di database (deteksi duplikat).
  static CsvImportResult parse(
    String content, {
    required Map<String, int> classByName,
    required Set<String> existingNis,
  }) {
    const CsvToListConverter converter = CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
    );
    final List<List<dynamic>> rows = converter.convert(content);

    final List<CsvRowResult> results = <CsvRowResult>[];
    int ok = 0;
    int err = 0;

    final int headerIndex = _findHeaderRow(rows);
    final int startRow = headerIndex == -1 ? 0 : headerIndex + 1;

    for (int i = startRow; i < rows.length; i++) {
      final List<dynamic> row = rows[i];
      final int rowNumber = i + 1;

      if (row.length < 3) {
        if (row.every((dynamic c) => c == null || c.toString().trim().isEmpty)) {
          continue; // baris kosong
        }
        err++;
        results.add(CsvRowResult(rowNumber: rowNumber, error: 'Kolom kurang lengkap.'));
        continue;
      }

      final String nis = _clean(row, 0);
      final String nisn = _clean(row, 1);
      final String name = _clean(row, 2);
      final String gender = normalizeGender(row.length > 3 ? _clean(row, 3) : 'L');
      final String className = row.length > 4 ? _clean(row, 4) : '';
      final String phone = row.length > 5 ? _clean(row, 5) : '';
      final String status = normalizeStatus(row.length > 6 ? _clean(row, 6) : 'aktif');

      String? error;
      if (nis.isEmpty) {
        error = 'NIS kosong.';
      } else if (existingNis.contains(nis)) {
        error = 'NIS $nis sudah ada di database.';
      } else if (name.isEmpty) {
        error = 'Nama kosong.';
      } else if (className.isNotEmpty && !classByName.containsKey(className)) {
        error = 'Kelas "$className" tidak ditemukan.';
      }

      if (error != null) {
        err++;
        results.add(CsvRowResult(rowNumber: rowNumber, nis: nis, name: name, error: error));
        continue;
      }

      existingNis.add(nis);
      final int? classId = className.isEmpty ? null : classByName[className];
      ok++;
      results.add(
        CsvRowResult(
          rowNumber: rowNumber,
          nis: nis,
          name: name,
          payload: <String, Object?>{
            'nis': nis,
            'nisn': nisn.isEmpty ? null : nisn,
            'name': name,
            'gender': gender,
            'class_id': classId,
            'major_id': null,
            'parent_name': null,
            'phone': phone.isEmpty ? null : phone,
            'address': null,
            'status': status,
          },
        ),
      );
    }

    return CsvImportResult(rows: results, successCount: ok, errorCount: err);
  }

  static String _clean(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    final dynamic v = row[index];
    return v == null ? '' : v.toString().trim();
  }

  /// Cari baris header (mengandung "nama" atau ("nis" + "kelas")).
  static int _findHeaderRow(List<List<dynamic>> rows) {
    for (int i = 0; i < rows.length && i < 5; i++) {
      final String joined = rows[i].whereType<String>().join(' ').toLowerCase();
      if (joined.contains('nama') ||
          (joined.contains('nis') && joined.contains('kelas'))) {
        return i;
      }
    }
    return -1;
  }

  static String normalizeGender(String value) {
    final String v = value.trim().toLowerCase();
    if (v.startsWith('p') || v.startsWith('per')) return 'P';
    if (v.startsWith('l')) return 'L';
    return 'L';
  }

  static String normalizeStatus(String value) {
    final String v = value.trim().toLowerCase();
    if (v.contains('cuti')) return 'cuti';
    if (v.contains('lulus')) return 'lulus';
    return 'aktif';
  }
}