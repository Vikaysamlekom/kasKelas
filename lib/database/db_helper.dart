import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/app_error.dart';
import '../core/constants.dart';

/// Terjemahkan [DatabaseException] menjadi pesan yang bisa dipahami pengguna.
String pesanDatabase(DatabaseException e, String konteks) {
  final String bawah = e.toString();
  if (e.isUniqueConstraintError() ||
      bawah.contains('UNIQUE constraint failed')) {
    return 'Data sudah ada (nilai duplikat). Periksa kembali input Anda.';
  }
  if (e.isNotNullConstraintError() || bawah.contains('NOT NULL')) {
    return 'Ada data wajib yang belum diisi.';
  }
  if (bawah.contains('FOREIGN KEY') || bawah.contains('no such table')) {
    return 'Data masih terhubung dengan data lain atau tabel belum tersedia. '
        'Coba muat ulang aplikasi.';
  }
  return '$konteks gagal. Silakan coba lagi.';
}

/// Singleton helper SQLite untuk aplikasi Kas Bintang Nusantara.
/// Mengelola pembuatan database, skema 12 tabel, dan data awal (seeding).
class DBHelper {
  DBHelper._();

  static final DBHelper instance = DBHelper._();

  static const String tblUsers = 'users';
  static const String tblMajors = 'majors';
  static const String tblClasses = 'classes';
  static const String tblStudents = 'students';
  static const String tblCashTypes = 'cash_types';
  static const String tblPayments = 'payments';
  static const String tblExpenseCategories = 'expense_categories';
  static const String tblExpenses = 'expenses';
  static const String tblAuditLogs = 'audit_logs';
  static const String tblSchoolProfile = 'school_profile';
  static const String tblSettings = 'settings';

  Database? _db;

  /// Nama file database alternatif. Hanya dipakai oleh pengujian agar
  /// beberapa file test tidak saling menimpa file yang sama.
  /// Nilai `null` (default aplikasi) memakai [AppConstants.dbName].
  @visibleForTesting
  static String? dbNameOverride;

  static String get _dbFileName => dbNameOverride ?? AppConstants.dbName;

  Future<Database> get database async => _db ??= await _openDatabase();

  Future<Database> _openDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = p.join(dbPath, _dbFileName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createSchema(db);
        await _seedData(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Migrasi: versi 1 → 2 menambah dukungan foto nota & pembatalan.
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $tblExpenses ADD COLUMN photo_path TEXT');
          await db.execute(
            "ALTER TABLE $tblExpenses ADD COLUMN status TEXT NOT NULL DEFAULT 'valid'",
          );
          await db.execute(
            'ALTER TABLE $tblExpenses ADD COLUMN void_reason TEXT',
          );
          await db.execute(
            'ALTER TABLE $tblPayments ADD COLUMN void_reason TEXT',
          );
        }
        // Migrasi: versi 2 → 3 menambah index untuk query laporan & list
        // panjang (lazy loading siswa).
        if (oldVersion < 3) {
          await _createIndexes(db);
        }
        // Migrasi: versi 3 → 4 mengosongkan nominal bawaan jenis kas supaya
        // tunggakan tidak terisi otomatis (mis. 25.000 + 10.000 = 35.000).
        // Hanya diubah bila masih bernilai bawaan, agar nominal yang sudah
        // diatur bendahara tidak ikut terhapus.
        if (oldVersion < 4) {
          const List<(String, int)> bawaanLama = <(String, int)>[
            ('BULANAN', 25000),
            ('TAHUNAN', 150000),
            ('SOSIAL', 10000),
          ];
          for (final (String, int) item in bawaanLama) {
            await db.update(
              tblCashTypes,
              <String, Object?>{'amount': 0},
              where: 'code = ? AND amount = ?',
              whereArgs: <Object?>[item.$1, item.$2],
            );
          }
        }
        // Migrasi: versi 4 → 5 — tidak ada PIN bawaan lagi. Hash kata sandi
        // bawaan lama dikosongkan agar pengguna diminta membuat PIN sendiri.
        // PIN yang sudah dipilih pengguna sendiri tetap dipertahankan.
        if (oldVersion < 5) {
          final List<Map<String, Object?>> users = await db.query(tblUsers);
          for (final Map<String, Object?> u in users) {
            final String username = u['username'] as String;
            final String hash = (u['password_hash'] as String?) ?? '';
            if (hash.isEmpty) continue;
            if (hash != hashPassword(AppConstants.defaultPassword, username)) {
              continue;
            }
            await db.update(
              tblUsers,
              <String, Object?>{'password_hash': AppConstants.noPinHash},
              where: 'id = ?',
              whereArgs: <Object?>[u['id']],
            );
          }
        }
        // Migrasi: versi 5 → 6 menjadikan Kas Mingguan satu-satunya jenis
        // kas bawaan. Jenis lama yang belum pernah diubah dihapus bila belum
        // dipakai, atau dinonaktifkan bila memiliki riwayat pembayaran.
        if (oldVersion < 6) {
          await _migrateWeeklyCashTypeDefaults(db);
        }
      },
    );
  }

  Future<void> _migrateWeeklyCashTypeDefaults(Database db) async {
    const List<(String, String, String, int, String)> defaultLama =
        <(String, String, String, int, String)>[
          (
            'BULANAN',
            'Kas Bulanan',
            'bulanan',
            10,
            'Iuran kas rutin setiap bulan',
          ),
          (
            'TAHUNAN',
            'Kas Tahunan',
            'tahunan',
            31,
            'Iuran kas sekali dalam setahun',
          ),
          ('SOSIAL', 'Kas Sosial', 'bulanan', 15, 'Iuran kas sosial / bantuan'),
        ];

    for (final (
          String code,
          String name,
          String frequency,
          int dueDay,
          String description,
        )
        in defaultLama) {
      final List<Map<String, Object?>> rows = await db.query(
        tblCashTypes,
        where:
            'code = ? AND name = ? AND amount = 0 AND frequency = ? '
            'AND due_day = ? AND description = ? AND is_active = 1',
        whereArgs: <Object?>[code, name, frequency, dueDay, description],
      );
      for (final Map<String, Object?> row in rows) {
        final List<Map<String, Object?>> payments = await db.query(
          tblPayments,
          columns: <String>['id'],
          where: 'cash_type_id = ?',
          whereArgs: <Object?>[row['id']],
          limit: 1,
        );
        if (payments.isEmpty) {
          await db.delete(
            tblCashTypes,
            where: 'id = ?',
            whereArgs: <Object?>[row['id']],
          );
        } else {
          await db.update(
            tblCashTypes,
            <String, Object?>{'is_active': 0},
            where: 'id = ?',
            whereArgs: <Object?>[row['id']],
          );
        }
      }
    }

    final List<Map<String, Object?>> weekly = await db.query(
      tblCashTypes,
      columns: <String>['id'],
      where: 'code = ?',
      whereArgs: <Object?>['MINGGUAN'],
      limit: 1,
    );
    if (weekly.isEmpty) {
      await db.insert(tblCashTypes, <String, Object?>{
        'name': 'Kas Mingguan',
        'code': 'MINGGUAN',
        'amount': 0,
        'frequency': 'mingguan',
        'due_day': 10,
        'description': 'Iuran kas rutin setiap minggu',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ------------------------------------------------------------------
  // SKEMA
  // ------------------------------------------------------------------

  Future<void> _createSchema(Database db) async {
    final List<String> statements = <String>[
      // 1. USERS
      '''
      CREATE TABLE $tblUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        nip TEXT,
        role TEXT NOT NULL DEFAULT 'bendahara',
        is_active INTEGER NOT NULL DEFAULT 1,
        last_login TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',

      // 2. MAJORS (Jurusan)
      '''
      CREATE TABLE $tblMajors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
      ''',

      // 3. CLASSES (Kelas)
      '''
      CREATE TABLE $tblClasses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        level INTEGER NOT NULL,
        major_id INTEGER,
        academic_year TEXT NOT NULL,
        homeroom_teacher TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (major_id) REFERENCES $tblMajors (id) ON DELETE SET NULL
      )
      ''',

      // 4. STUDENTS (Siswa)
      '''
      CREATE TABLE $tblStudents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nis TEXT NOT NULL UNIQUE,
        nisn TEXT,
        name TEXT NOT NULL,
        gender TEXT NOT NULL DEFAULT 'L',
        class_id INTEGER,
        major_id INTEGER,
        parent_name TEXT,
        phone TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'aktif',
        join_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES $tblClasses (id) ON DELETE SET NULL,
        FOREIGN KEY (major_id) REFERENCES $tblMajors (id) ON DELETE SET NULL
      )
      ''',

      // 5. CASH_TYPES (Jenis Kas / Iuran)
      '''
      CREATE TABLE $tblCashTypes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        frequency TEXT NOT NULL DEFAULT 'mingguan',
        due_day INTEGER NOT NULL DEFAULT 10,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
      ''',

      // 6. PAYMENTS (Pembayaran)
      '''
      CREATE TABLE $tblPayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_code TEXT NOT NULL UNIQUE,
        student_id INTEGER NOT NULL,
        cash_type_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        paid_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'tunai',
        status TEXT NOT NULL DEFAULT 'lunas',
        note TEXT,
        void_reason TEXT,
        recorded_by INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES $tblStudents (id) ON DELETE CASCADE,
        FOREIGN KEY (cash_type_id) REFERENCES $tblCashTypes (id) ON DELETE RESTRICT,
        FOREIGN KEY (recorded_by) REFERENCES $tblUsers (id) ON DELETE SET NULL
      )
      ''',

      // 7. EXPENSE_CATEGORIES (Kategori Pengeluaran)
      '''
      CREATE TABLE $tblExpenseCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
      ''',

      // 8. EXPENSES (Pengeluaran)
      '''
      CREATE TABLE $tblExpenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_code TEXT NOT NULL UNIQUE,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        expense_date TEXT NOT NULL,
        description TEXT NOT NULL,
        receipt_note TEXT,
        photo_path TEXT,
        status TEXT NOT NULL DEFAULT 'valid',
        void_reason TEXT,
        recorded_by INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES $tblExpenseCategories (id) ON DELETE RESTRICT,
        FOREIGN KEY (recorded_by) REFERENCES $tblUsers (id) ON DELETE SET NULL
      )
      ''',

      // 9. AUDIT_LOGS (Jejak Audit)
      '''
      CREATE TABLE $tblAuditLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        entity_table TEXT NOT NULL,
        entity_id INTEGER,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tblUsers (id) ON DELETE SET NULL
      )
      ''',

      // 10. SCHOOL_PROFILE (Profil Sekolah)
      '''
      CREATE TABLE $tblSchoolProfile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_name TEXT NOT NULL,
        npsn TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        headmaster TEXT,
        treasurer TEXT,
        logo_path TEXT,
        updated_at TEXT NOT NULL
      )
      ''',

      // 11. SETTINGS (Pengaturan)
      '''
      CREATE TABLE $tblSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT,
        description TEXT,
        updated_at TEXT NOT NULL
      )
      ''',
    ];

    for (final String sql in statements) {
      await db.execute(sql);
    }

    await _createIndexes(db);
  }

  /// Index untuk performa query. Dipisah agar bisa dipanggil ulang saat
  /// migrasi database lama.
  Future<void> _createIndexes(Database db) async {
    // Pembayaran: filter per siswa, periode (tahun+bulan), status, dan tanggal.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_student ON $tblPayments (student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_period ON $tblPayments (year, month)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_status ON $tblPayments (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_cash_type ON $tblPayments (cash_type_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_paid_date ON $tblPayments (paid_date)',
    );
    // Laporan saldo/pengeluaran memakai substr(paid_date/expense_date, 1, 10).
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_paid_date_prefix ON $tblPayments (substr(paid_date, 1, 10))',
    );

    // Pengeluaran: filter tanggal, kategori, status.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON $tblExpenses (expense_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON $tblExpenses (category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_status ON $tblExpenses (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date_prefix ON $tblExpenses (substr(expense_date, 1, 10))',
    );

    // Siswa: pencarian nama/NIS, filter kelas & status.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_class ON $tblStudents (class_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_status ON $tblStudents (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_name ON $tblStudents (name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_nis ON $tblStudents (nis)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_class_name ON $tblStudents (class_id, name)',
    );

    // Kelas & jurusan untuk JOIN / filter.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_classes_major ON $tblClasses (major_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_classes_level ON $tblClasses (level)',
    );

    // Kategori pengeluaran & jenis kas (filter aktif).
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expense_categories_active ON $tblExpenseCategories (is_active, name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_types_active ON $tblCashTypes (is_active, name)',
    );

    // Audit log: urut waktu terbaru.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_created ON $tblAuditLogs (created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_entity ON $tblAuditLogs (entity_table, entity_id)',
    );
  }

  // ------------------------------------------------------------------
  // SEEDING DATA AWAL
  // ------------------------------------------------------------------

  Future<void> _seedData(Database db) async {
    final String now = DateTime.now().toIso8601String();

    // Akun bendahara default — TANPA PIN bawaan (`password_hash` kosong).
    // Pengguna diminta membuat PIN sendiri saat pertama membuka aplikasi.
    await db.insert(tblUsers, <String, Object?>{
      'username': AppConstants.defaultUsername,
      'password_hash': AppConstants.noPinHash,
      'full_name': AppConstants.defaultFullName,
      'nip': AppConstants.defaultNip,
      'role': 'bendahara',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Profil sekolah
    await db.insert(tblSchoolProfile, <String, Object?>{
      'school_name': 'SMK Bintang Nusantara',
      'npsn': '0000000000',
      'address': '',
      'phone': '',
      'email': '',
      'headmaster': '',
      'treasurer': AppConstants.defaultFullName,
      'updated_at': now,
    });

    // Pengaturan awal
    final Map<String, String> settings = <String, String>{
      'app_version': AppConstants.appVersion,
      'academic_year': '2026/2027',
      'active_month': DateTime.now().month.toString(),
      'active_year': DateTime.now().year.toString(),
      'school_name': 'SMK Bintang Nusantara',
      'treasurer_name': AppConstants.defaultFullName,
      'auto_lock_minutes': '5',
    };
    for (final MapEntry<String, String> e in settings.entries) {
      await db.insert(tblSettings, <String, Object?>{
        'key': e.key,
        'value': e.value,
        'description': null,
        'updated_at': now,
      });
    }

    // Jenis kas mingguan sebagai satu-satunya bawaan.
    //
    // Nominal sengaja DIBIARKAN 0 (bukan 25.000/10.000 dst.) supaya aplikasi
    // tidak menetapkan tunggakan secara otomatis. Bendahara mengisi nominal
    // kas sesuai keadaan sekolah di menu "Jenis Kas".
    final List<Map<String, Object?>> cashTypes = <Map<String, Object?>>[
      <String, Object?>{
        'name': 'Kas Mingguan',
        'code': 'MINGGUAN',
        'amount': 0,
        'frequency': 'mingguan',
        'due_day': 10,
        'description': 'Iuran kas rutin setiap minggu',
      },
    ];
    for (final Map<String, Object?> row in cashTypes) {
      await db.insert(tblCashTypes, <String, Object?>{
        ...row,
        'is_active': 1,
        'created_at': now,
      });
    }

    // Kategori pengeluaran default
    final List<String> categories = <String>[
      'Operasional',
      'ATK',
      'Sosial / Bansos',
      'Kegiatan',
      'Pemeliharaan',
      'Lainnya',
    ];
    for (final String name in categories) {
      await db.insert(tblExpenseCategories, <String, Object?>{
        'name': name,
        'description': null,
        'is_active': 1,
        'created_at': now,
      });
    }
  }

  /// Hash password dengan SHA-256 (salt = username, untuk verifikasi login).
  static String hashPassword(String raw, String username) {
    final String salted = '@$username:$raw';
    return sha256.convert(utf8.encode(salted)).toString();
  }

  static bool verifyPassword(String raw, String username, String hash) {
    return hashPassword(raw, username) == hash;
  }

  // ------------------------------------------------------------------
  // GENERIC CRUD
  // ------------------------------------------------------------------

  Future<int> insert(String table, Map<String, Object?> values) {
    return _safe(
      () async {
        final Database db = await database;
        return db.insert(table, values);
      },
      'Menyimpan ke $table',
    );
  }

  /// Error handling terpusat untuk setiap operasi database.
  /// Semua error (DatabaseException, dll) dicatat ke log lalu dibungkus
  /// menjadi [AppException] dengan pesan ramah pengguna.
  Future<T> _safe<T>(Future<T> Function() action, String konteks) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      debugPrint('[DB] $konteks: ${e.result ?? e.isUniqueConstraintError} ($e)');
      throw AppException(
        pesanDatabase(e, konteks),
        cause: e,
        stackTrace: StackTrace.current,
      );
    } catch (e, stack) {
      debugPrint('[DB] $konteks: $e\n$stack');
      throw AppException(
        '$konteks gagal: $e',
        cause: e,
        stackTrace: stack,
      );
    }
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _safe(
      () async {
        final Database db = await database;
        return db.query(
          table,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        );
      },
      'Membaca tabel $table',
    );
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _safe(
      () async {
        final Database db = await database;
        return db.rawQuery(sql, arguments);
      },
      'Menjalankan query',
    );
  }

  Future<Map<String, Object?>?> queryOne(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _safe(
      () async {
        final Database db = await database;
        final List<Map<String, Object?>> rows = await db.query(
          table,
          where: where,
          whereArgs: whereArgs,
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first;
      },
      'Membaca data $table',
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    return _safe(
      () async {
        final Database db = await database;
        return db.update(table, values, where: where, whereArgs: whereArgs);
      },
      'Memperbarui $table',
    );
  }

  Future<int> delete(
    String table, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    return _safe(
      () async {
        final Database db = await database;
        return db.delete(table, where: where, whereArgs: whereArgs);
      },
      'Menghapus $table',
    );
  }

  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) {
    return _safe(
      () async {
        final Database db = await database;
        final List<Map<String, Object?>> result = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $table${where != null ? ' WHERE $where' : ''}',
          whereArgs,
        );
        return Sqflite.firstIntValue(result) ?? 0;
      },
      'Menghitung $table',
    );
  }

  Future<int> sum(
    String table,
    String column, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _safe(
      () async {
        final Database db = await database;
        final List<Map<String, Object?>> result = await db.rawQuery(
          'SELECT COALESCE(SUM($column), 0) AS s FROM $table${where != null ? ' WHERE $where' : ''}',
          whereArgs,
        );
        return Sqflite.firstIntValue(result) ?? 0;
      },
      'Menjumlahkan $column',
    );
  }

  Future<void> transaction(Future<void> Function(Transaction txn) action) {
    return _safe(
      () async {
        final Database db = await database;
        await db.transaction((Transaction txn) => action(txn));
      },
      'Menyimpan transaksi data',
    );
  }

  // ------------------------------------------------------------------
  // UTILITAS
  // ------------------------------------------------------------------

  /// Ambil nilai setting berdasarkan key.
  Future<String?> getSetting(String key) async {
    final Map<String, Object?>? row = await queryOne(
      tblSettings,
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
    return row?['value'] as String?;
  }

  /// Simpan / perbarui nilai setting.
  Future<void> setSetting(String key, String value) async {
    final String now = DateTime.now().toIso8601String();
    final int updated = await update(
      tblSettings,
      <String, Object?>{'value': value, 'updated_at': now},
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
    if (updated == 0) {
      await insert(tblSettings, <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': now,
      });
    }
  }

  /// Catat aktivitas ke audit_logs.
  Future<void> logAudit({
    required int? userId,
    required String action,
    required String entityTable,
    int? entityId,
    String? description,
  }) async {
    await insert(tblAuditLogs, <String, Object?>{
      'user_id': userId,
      'action': action,
      'entity_table': entityTable,
      'entity_id': entityId,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
