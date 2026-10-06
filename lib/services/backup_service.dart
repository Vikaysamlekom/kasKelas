import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_error.dart';
import '../core/constants.dart';
import '../database/db_helper.dart';

/// Kunci SharedPreferences untuk pengaturan backup otomatis.
class BackupPrefs {
  BackupPrefs._();

  static const String autoBackupEnabled = 'backup_auto_enabled';
  static const String autoBackupFrequency = 'backup_auto_frequency';
  static const String lastBackupDate = 'backup_last_date';
}

/// Frekuensi backup otomatis.
enum AutoBackupFrequency {
  mati,
  harian,
  mingguan;

  String get label => switch (this) {
        AutoBackupFrequency.mati => 'Mati',
        AutoBackupFrequency.harian => 'Harian',
        AutoBackupFrequency.mingguan => 'Mingguan',
      };

  String get prefValue => switch (this) {
        AutoBackupFrequency.mati => 'off',
        AutoBackupFrequency.harian => 'daily',
        AutoBackupFrequency.mingguan => 'weekly',
      };

  static AutoBackupFrequency fromPref(String? v) => switch (v) {
        'daily' => AutoBackupFrequency.harian,
        'weekly' => AutoBackupFrequency.mingguan,
        _ => AutoBackupFrequency.mati,
      };
}

/// Informasi file backup.
class BackupFile {
  final String path;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  const BackupFile({
    required this.path,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Layanan backup & restore database SQLite.
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const String _folder = 'backup';

  /// Nama file backup: backup_kas_bintang_nusantara_YYYY-MM-DD.db
  static String fileNameFor(DateTime date) {
    final String d = date.toIso8601String().substring(0, 10);
    return 'backup_${AppConstants.dbName.replaceAll('.db', '')}_$d.db';
  }

  Future<Directory> _backupDir() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory backup = Directory(p.join(dir.path, _folder));
    if (!backup.existsSync()) {
      await backup.create(recursive: true);
    }
    return backup;
  }

  Future<String> dbPath() async {
    final String base = await getDatabasesPath();
    return p.join(base, AppConstants.dbName);
  }

  /// Salin database ke file backup. Return path file hasil backup.
  /// Error dibungkus [AppException] agar pesan tampil ramah di UI.
  Future<String> backupNow({DateTime? pada}) {
    return DbSafe.run(
      () => _backupNow(pada: pada),
      'Backup database',
    );
  }

  Future<String> _backupNow({DateTime? pada}) async {
    final DateTime now = pada ?? DateTime.now();
    final Directory dir = await _backupDir();
    final File source = File(await dbPath());
    if (!source.existsSync()) {
      throw StateError('File database tidak ditemukan.');
    }
    final String target = p.join(dir.path, fileNameFor(now));
    // Hindari menimpa backup yang sudah ada (tambahkan suffix waktu).
    final String finalPath = await uniqueBackupPath(dir, target, now);
    await source.copy(finalPath);
    await _setLastBackup(now);
    return finalPath;
  }

  /// Tentukan path backup yang belum terpakai. Bila [target] sudah ada, tambahkan
  /// suffix waktu (HHMMSS), dan bila tetap bentrok tambahkan angka urut.
  @visibleForTesting
  static Future<String> uniqueBackupPath(
    Directory dir,
    String target,
    DateTime now,
  ) async {
    if (!await File(target).exists()) return target;

    final String base = p.basenameWithoutExtension(target);
    final String ext = p.extension(target);
    final String stamp =
        now.toIso8601String().substring(11, 19).replaceAll(':', '');

    String candidate = p.join(dir.path, '${base}_$stamp$ext');
    int urut = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '${base}_${stamp}_$urut$ext');
      urut++;
    }
    return candidate;
  }

  /// Daftar file backup. Bila terjadi kesalahan, mengembalikan daftar kosong
  /// agar UI tetap bisa digunakan.
  Future<List<BackupFile>> listBackupsSafe() {
    return DbSafe.runOr(
      () => listBackups(),
      'Membaca daftar backup',
      <BackupFile>[],
    );
  }

  Future<List<BackupFile>> listBackups() async {
    final Directory dir = await _backupDir();
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<File> files = entities
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.db'))
        .toList();

    final List<BackupFile> result = <BackupFile>[];
    for (final File f in files) {
      final FileStat stat = await f.stat();
      if (stat.type == FileSystemEntityType.file) {
        result.add(
          BackupFile(
            path: f.path,
            name: p.basename(f.path),
            modified: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    }
    result.sort(
      (BackupFile a, BackupFile b) => b.modified.compareTo(a.modified),
    );
    return result;
  }

  /// Restore database dari file backup.
  /// Database ditutup sementara, file dicopy ke lokasi DB, lalu dibuka kembali.
  Future<void> restore(String backupPath) {
    return DbSafe.run(
      () => _restore(backupPath),
      'Restore database',
    );
  }

  Future<void> _restore(String backupPath) async {
    final File source = File(backupPath);
    if (!source.existsSync()) {
      throw StateError('File backup tidak ditemukan.');
    }
    // Validasi file benar-benar database SQLite.
    final List<int> magic = await source.openRead(0, 15).fold<List<int>>(
          <int>[],
          (List<int> acc, List<int> chunk) => acc..addAll(chunk),
        );
    final String header = String.fromCharCodes(magic);
    if (!header.startsWith('SQLite format 3')) {
      throw StateError('File tersebut bukan backup database yang valid.');
    }

    // Simpan salinan keamanan sebelum menimpa.
    await backupNow();

    final String target = await dbPath();
    await DBHelper.instance.close();
    await source.copy(target);
    // Buka kembali koneksi ke database hasil restore.
    await DBHelper.instance.database;
  }

  Future<void> deleteBackup(String backupPath) async {
    final File f = File(backupPath);
    if (f.existsSync()) {
      await f.delete();
    }
  }

  // ------------------------------------------------------------------
  // BACKUP OTOMATIS (SharedPreferences)
  // ------------------------------------------------------------------

  Future<bool> isAutoBackupEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(BackupPrefs.autoBackupEnabled) ?? false;
  }

  Future<AutoBackupFrequency> autoBackupFrequency() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AutoBackupFrequency.fromPref(
      prefs.getString(BackupPrefs.autoBackupFrequency),
    );
  }

  Future<void> setAutoBackup({
    required bool enabled,
    required AutoBackupFrequency frequency,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BackupPrefs.autoBackupEnabled, enabled);
    await prefs.setString(BackupPrefs.autoBackupFrequency, frequency.prefValue);
    if (!enabled) {
      await prefs.remove(BackupPrefs.lastBackupDate);
    }
  }

  Future<String?> lastBackupDate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(BackupPrefs.lastBackupDate);
  }

  Future<void> _setLastBackup(DateTime date) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(BackupPrefs.lastBackupDate, date.toIso8601String().substring(0, 10));
  }

  /// Jalankan backup otomatis jika sudah Due. Dipanggil saat app dibuka.
  /// Return true jika backup dijalankan.
  Future<bool> runScheduledBackupIfDue() async {
    try {
      final bool enabled = await isAutoBackupEnabled();
      if (!enabled) return false;

      final AutoBackupFrequency freq = await autoBackupFrequency();
      if (freq == AutoBackupFrequency.mati) return false;

      final String? last = await lastBackupDate();
      final DateTime now = DateTime.now();
      final String today = now.toIso8601String().substring(0, 10);

      bool due = false;
      if (last == null) {
        due = true;
      } else if (freq == AutoBackupFrequency.harian) {
        due = last != today;
      } else {
        // Mingguan: due jika sudah lewat 7 hari.
        final DateTime lastDate = DateTime.parse(last);
        due = now.difference(lastDate).inDays >= 7;
      }

      if (!due) return false;

      await backupNow(pada: now);
      debugPrint('Backup otomatis dijalankan: $today');
      return true;
    } catch (e) {
      debugPrint('Gagal backup otomatis: $e');
      return false;
    }
  }

  /// Pesan ringkas untuk ditampilkan di UI.
  Future<String> lastBackupLabel() async {
    final String? last = await lastBackupDate();
    if (last == null) return 'Belum pernah';
    return last;
  }
}
