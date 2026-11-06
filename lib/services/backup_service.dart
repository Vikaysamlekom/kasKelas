import 'dart:async';
import 'dart:convert';
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
  static const String lastAutoBackupError = 'backup_last_auto_error';
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

  /// Format file backup khusus web. Berisi seluruh isi tabel dalam JSON,
  /// karena file database SQLite web berada di IndexedDB dan tidak bisa
  /// disalin seperti file biasa.
  static const String webBackupFormat = 'kas-bintang-nusantara-backup';
  static const int webBackupVersion = 1;
  static const String _webAutoBackupDbName =
      'kas_bintang_nusantara_web_backups.db';
  static const int webAutoBackupRetention = 7;

  Database? _webAutoBackupDb;

  /// Nama file backup: backup_kas_bintang_nusantara_YYYY-MM-DD.db
  static String fileNameFor(DateTime date) {
    final String d = date.toIso8601String().substring(0, 10);
    return 'backup_${AppConstants.dbName.replaceAll('.db', '')}_$d.db';
  }

  /// Nama file backup JSON untuk web.
  static String webFileNameFor(DateTime date) {
    final String d = date.toIso8601String().substring(0, 10);
    return 'backup_${AppConstants.dbName.replaceAll('.db', '')}_$d.json';
  }

  /// Backup data untuk web: seluruh tabel diekspor sebagai JSON.
  Future<Uint8List> createWebBackup({DateTime? pada}) {
    return DbSafe.run(() => _createWebBackup(pada: pada), 'Backup database');
  }

  Future<Uint8List> _createWebBackup({DateTime? pada}) async {
    final DateTime now = pada ?? DateTime.now();
    final Database db = await DBHelper.instance.database;
    final List<Map<String, Object?>> tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' "
      "AND name != 'android_metadata' "
      "ORDER BY name",
    );

    final Map<String, List<Map<String, Object?>>> tables =
        <String, List<Map<String, Object?>>>{};
    for (final Map<String, Object?> row in tableRows) {
      final String name = row['name'] as String;
      tables[name] = await db.query(name);
    }

    final Map<String, Object?> payload = <String, Object?>{
      'format': webBackupFormat,
      'version': webBackupVersion,
      'app': AppConstants.appName,
      'db_version': AppConstants.dbVersion,
      'exported_at': now.toIso8601String(),
      'tables': tables,
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  Future<Database> _webAutoBackupDatabase() async {
    if (!kIsWeb) {
      throw StateError('Penyimpanan backup browser hanya tersedia di web.');
    }
    if (_webAutoBackupDb != null) return _webAutoBackupDb!;

    await DBHelper.instance.database;
    _webAutoBackupDb = await openDatabase(
      _webAutoBackupDbName,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE web_auto_backups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            payload BLOB NOT NULL
          )
        ''');
      },
    );
    return _webAutoBackupDb!;
  }

  Future<void> _saveWebAutoBackup(DateTime date) async {
    final Uint8List bytes = await _createWebBackup(pada: date);
    final Database db = await _webAutoBackupDatabase();
    await db.transaction((Transaction txn) async {
      await txn.insert('web_auto_backups', <String, Object?>{
        'created_at': date.toIso8601String(),
        'payload': bytes,
      });
      await txn.rawDelete(
        'DELETE FROM web_auto_backups WHERE id NOT IN '
        '(SELECT id FROM web_auto_backups ORDER BY id DESC LIMIT ?)',
        <Object?>[webAutoBackupRetention],
      );
    });

    await _setLastBackup(date);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(BackupPrefs.lastAutoBackupError);
  }

  Future<List<BackupFile>> listWebAutoBackups() async {
    final Database db = await _webAutoBackupDatabase();
    final List<Map<String, Object?>> rows = await db.query(
      'web_auto_backups',
      columns: <String>['id', 'created_at', 'length(payload) AS size_bytes'],
      orderBy: 'id DESC',
    );
    return rows.map((Map<String, Object?> row) {
      final DateTime created = DateTime.parse(row['created_at'] as String);
      return BackupFile(
        path: (row['id'] as int).toString(),
        name: webFileNameFor(created),
        modified: created,
        sizeBytes: row['size_bytes'] as int,
      );
    }).toList();
  }

  Future<Uint8List> webAutoBackupBytes(String id) async {
    final int? backupId = int.tryParse(id);
    if (backupId == null) {
      throw const AppException('Backup browser tidak valid.');
    }
    final Database db = await _webAutoBackupDatabase();
    final List<Map<String, Object?>> rows = await db.query(
      'web_auto_backups',
      columns: <String>['payload'],
      where: 'id = ?',
      whereArgs: <Object?>[backupId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppException('Backup otomatis tidak ditemukan.');
    }
    return Uint8List.fromList(rows.first['payload'] as List<int>);
  }

  Future<void> restoreWebAutoBackup(String id) async {
    await restoreWebBackup(await webAutoBackupBytes(id));
  }

  Future<void> deleteWebAutoBackup(String id) async {
    final int? backupId = int.tryParse(id);
    if (backupId == null) {
      throw const AppException('Backup browser tidak valid.');
    }
    final Database db = await _webAutoBackupDatabase();
    await db.delete(
      'web_auto_backups',
      where: 'id = ?',
      whereArgs: <Object?>[backupId],
    );
  }

  /// Restore data web dari file backup JSON.
  Future<void> restoreWebBackup(Uint8List bytes) {
    return DbSafe.run(() => _restoreWebBackup(bytes), 'Restore database');
  }

  Future<void> _restoreWebBackup(Uint8List bytes) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const AppException('File backup bukan JSON yang valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AppException('Struktur file backup tidak dikenali.');
    }
    if (decoded['format'] != webBackupFormat) {
      throw const AppException(
        'File tersebut bukan backup Kas Bintang Nusantara.',
      );
    }

    final Object? versionValue = decoded['version'];
    final int version = versionValue is int ? versionValue : 0;
    if (version < 1 || version > webBackupVersion) {
      throw AppException(
        'Versi backup ($version) tidak didukung aplikasi ini.',
      );
    }

    final Object? tablesValue = decoded['tables'];
    if (tablesValue is! Map) {
      throw const AppException('File backup tidak berisi data tabel.');
    }

    final Map<String, List<Map<String, Object?>>> tables =
        <String, List<Map<String, Object?>>>{};
    for (final MapEntry<dynamic, dynamic> entry in tablesValue.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const AppException(
          'Struktur data tabel pada backup tidak valid.',
        );
      }
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
      for (final dynamic row in entry.value as List<dynamic>) {
        if (row is! Map) {
          throw const AppException('Ada baris data backup yang tidak valid.');
        }
        final Map<String, Object?> mapped = <String, Object?>{};
        row.forEach((dynamic key, dynamic value) {
          if (key is String) mapped[key] = value;
        });
        rows.add(mapped);
      }
      tables[entry.key as String] = rows;
    }

    // Tabel users wajib ada agar hasil restore tidak mengosongkan akun.
    final Database db = await DBHelper.instance.database;
    final List<Map<String, Object?>> existingRows = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' "
      "AND name != 'android_metadata'",
    );
    final Set<String> existingTables = existingRows
        .map((Map<String, Object?> row) => row['name'] as String)
        .toSet();

    validateWebBackupTables(
      backupTables: tables.keys.toSet(),
      existingTables: existingTables,
    );

    // Matikan foreign key selama penggantian agar urutan hapus/insert tidak
    // menjadi masalah, lalu nyalakan kembali.
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((Transaction txn) async {
        for (final String name in existingTables) {
          await txn.delete(name);
        }
        for (final MapEntry<String, List<Map<String, Object?>>> entry
            in tables.entries) {
          for (final Map<String, Object?> row in entry.value) {
            await txn.insert(
              entry.key,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  @visibleForTesting
  static void validateWebBackupTables({
    required Set<String> backupTables,
    required Set<String> existingTables,
  }) {
    if (!backupTables.contains(DBHelper.tblUsers)) {
      throw const AppException('Backup tidak berisi tabel pengguna.');
    }

    final Set<String> unknown = backupTables.difference(existingTables);
    if (unknown.isNotEmpty) {
      final String name = unknown.first;
      throw AppException(
        'Tabel "$name" pada backup tidak dikenal oleh aplikasi ini.',
      );
    }

    final Set<String> missing = existingTables.difference(backupTables);
    if (missing.isNotEmpty) {
      final List<String> names = missing.toList()..sort();
      throw AppException(
        'Backup tidak berisi semua tabel yang diperlukan: ${names.join(', ')}.',
      );
    }
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
    return DbSafe.run(() => _backupNow(pada: pada), 'Backup database');
  }

  Future<String> _backupNow({DateTime? pada}) async {
    if (kIsWeb) {
      throw const AppException(
        'Backup file database tidak tersedia di web. '
        'Gunakan Unduh Backup (JSON).',
      );
    }
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
    final String stamp = now
        .toIso8601String()
        .substring(11, 19)
        .replaceAll(':', '');

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
    if (kIsWeb) return <BackupFile>[];
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
    return DbSafe.run(() => _restore(backupPath), 'Restore database');
  }

  Future<void> _restore(String backupPath) async {
    if (kIsWeb) {
      throw const AppException(
        'Restore file .db tidak tersedia di web. '
        'Gunakan Restore dari File JSON.',
      );
    }
    final File source = File(backupPath);
    if (!source.existsSync()) {
      throw StateError('File backup tidak ditemukan.');
    }
    // Validasi file benar-benar database SQLite.
    final List<int> magic = await source
        .openRead(0, 15)
        .fold<List<int>>(
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
    final bool wasEnabled =
        prefs.getBool(BackupPrefs.autoBackupEnabled) ?? false;
    await prefs.setBool(BackupPrefs.autoBackupEnabled, enabled);
    await prefs.setString(BackupPrefs.autoBackupFrequency, frequency.prefValue);
    if (!enabled) {
      await prefs.remove(BackupPrefs.lastBackupDate);
    } else if (kIsWeb && !wasEnabled) {
      await prefs.remove(BackupPrefs.lastBackupDate);
      await prefs.remove(BackupPrefs.lastAutoBackupError);
    }
  }

  Future<String?> lastBackupDate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(BackupPrefs.lastBackupDate);
  }

  Future<void> _setLastBackup(DateTime date) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      BackupPrefs.lastBackupDate,
      date.toIso8601String().substring(0, 10),
    );
  }

  /// Jalankan backup otomatis jika sudah Due. Dipanggil saat app dibuka.
  /// Return true jika backup dijalankan.
  Future<bool> runScheduledBackupIfDue() async {
    try {
      final bool enabled = await isAutoBackupEnabled();
      if (!enabled) return false;

      final AutoBackupFrequency freq = await autoBackupFrequency();
      final String? last = await lastBackupDate();
      final DateTime now = DateTime.now();
      final String today = now.toIso8601String().substring(0, 10);
      if (!isBackupDue(frequency: freq, lastBackup: last, now: now)) {
        return false;
      }

      if (kIsWeb) {
        await _saveWebAutoBackup(now);
      } else {
        await backupNow(pada: now);
      }
      debugPrint('Backup otomatis dijalankan: $today');
      return true;
    } catch (e) {
      debugPrint('Gagal backup otomatis: $e');
      if (kIsWeb) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(BackupPrefs.lastAutoBackupError, e.toString());
      }
      return false;
    }
  }

  @visibleForTesting
  static bool isBackupDue({
    required AutoBackupFrequency frequency,
    required String? lastBackup,
    required DateTime now,
  }) {
    if (frequency == AutoBackupFrequency.mati) return false;
    if (lastBackup == null) return true;

    final String today = now.toIso8601String().substring(0, 10);
    if (frequency == AutoBackupFrequency.harian) {
      return lastBackup != today;
    }

    final DateTime? lastDate = DateTime.tryParse(lastBackup);
    return lastDate == null || now.difference(lastDate).inDays >= 7;
  }

  Future<String?> lastAutoBackupError() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(BackupPrefs.lastAutoBackupError);
  }

  /// Pesan ringkas untuk ditampilkan di UI.
  Future<String> lastBackupLabel() async {
    final String? last = await lastBackupDate();
    if (last == null) return 'Belum pernah';
    return last;
  }
}
