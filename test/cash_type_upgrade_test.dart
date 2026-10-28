import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const String dbName = 'cash_type_upgrade_test.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    final String base = await getDatabasesPath();
    final File dbFile = File(p.join(base, dbName));
    for (final String suffix in <String>['', '-journal', '-wal', '-shm']) {
      final File file = File('${dbFile.path}$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  });

  test(
    'upgrade sets monthly default and preserves customized data and history',
    () async {
      await DBHelper.instance.close();
      DBHelper.dbNameOverride = dbName;
      final String base = await getDatabasesPath();
      final File dbFile = File(p.join(base, dbName));
      if (dbFile.existsSync()) dbFile.deleteSync();

      final Database oldDb = await openDatabase(
        dbFile.path,
        version: 5,
        onCreate: (Database db, int version) async {
          await db.execute('''
          CREATE TABLE cash_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            amount INTEGER NOT NULL DEFAULT 0,
            frequency TEXT NOT NULL DEFAULT 'bulanan',
            due_day INTEGER NOT NULL DEFAULT 10,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cash_type_id INTEGER NOT NULL,
            month INTEGER NOT NULL DEFAULT 1,
            year INTEGER NOT NULL DEFAULT 2026,
            paid_date TEXT NOT NULL DEFAULT '2026-01-01'
          )
        ''');

          final String now = DateTime.now().toIso8601String();
          final List<Map<String, Object?>> oldDefaults = <Map<String, Object?>>[
            <String, Object?>{
              'name': 'Kas Bulanan',
              'code': 'BULANAN',
              'frequency': 'bulanan',
              'due_day': 10,
              'description': 'Iuran kas rutin setiap bulan',
            },
            <String, Object?>{
              'name': 'Kas Tahunan',
              'code': 'TAHUNAN',
              'frequency': 'tahunan',
              'due_day': 31,
              'description': 'Iuran kas sekali dalam setahun',
            },
            <String, Object?>{
              'name': 'Kas Sosial',
              'code': 'SOSIAL',
              'frequency': 'bulanan',
              'due_day': 15,
              'description': 'Iuran kas sosial / bantuan',
            },
          ];
          int? idKasSosial;
          for (final Map<String, Object?> item in oldDefaults) {
            final int id = await db.insert('cash_types', <String, Object?>{
              ...item,
              'amount': 0,
              'is_active': 1,
              'created_at': now,
            });
            if (item['code'] == 'SOSIAL') idKasSosial = id;
          }
          await db.insert('cash_types', <String, Object?>{
            'name': 'Kas Bulanan Khusus',
            'code': 'BULANAN',
            'amount': 25000,
            'frequency': 'bulanan',
            'due_day': 10,
            'description': 'Nominal yang sudah disesuaikan',
            'is_active': 1,
            'created_at': now,
          });
          await db.insert('payments', <String, Object?>{
            'cash_type_id': idKasSosial,
          });
        },
      );
      await oldDb.close();

      final Database upgraded = await DBHelper.instance.database;
      final List<Map<String, Object?>> allTypes = await upgraded.query(
        'cash_types',
        orderBy: 'name',
      );
      final List<Map<String, Object?>> activeTypes = allTypes
          .where((Map<String, Object?> item) => item['is_active'] == 1)
          .toList();

      expect(
        activeTypes.map((Map<String, Object?> item) => item['name']),
        containsAll(<String>['Kas Bulanan', 'Kas Bulanan Khusus']),
      );
      expect(activeTypes, hasLength(2));
      final Map<String, Object?> kasBulanan = allTypes.singleWhere(
        (Map<String, Object?> item) => item['name'] == 'Kas Bulanan',
      );
      expect(kasBulanan['amount'], 10000);
      expect(kasBulanan['frequency'], 'bulanan');
      expect(
        allTypes.singleWhere(
          (Map<String, Object?> item) => item['code'] == 'SOSIAL',
        )['is_active'],
        0,
      );
      expect(
        allTypes.any((Map<String, Object?> item) => item['code'] == 'TAHUNAN'),
        isFalse,
      );
      expect(await upgraded.query('payments'), hasLength(1));
    },
  );

  test(
    'upgrade from weekly default restores monthly and keeps old payments',
    () async {
      await DBHelper.instance.close();
      DBHelper.dbNameOverride = dbName;
      final String base = await getDatabasesPath();
      final File dbFile = File(p.join(base, dbName));
      if (dbFile.existsSync()) dbFile.deleteSync();

      final Database oldDb = await openDatabase(
        dbFile.path,
        version: 6,
        onCreate: (Database db, int version) async {
          await db.execute('''
          CREATE TABLE cash_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            amount INTEGER NOT NULL DEFAULT 0,
            frequency TEXT NOT NULL DEFAULT 'mingguan',
            due_day INTEGER NOT NULL DEFAULT 10,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cash_type_id INTEGER NOT NULL,
            month INTEGER NOT NULL DEFAULT 1,
            year INTEGER NOT NULL DEFAULT 2026,
            paid_date TEXT NOT NULL DEFAULT '2026-01-01'
          )
        ''');

          final int weeklyId = await db.insert('cash_types', <String, Object?>{
            'name': 'Kas Mingguan',
            'code': 'MINGGUAN',
            'amount': 0,
            'frequency': 'mingguan',
            'due_day': 10,
            'description': 'Iuran kas rutin setiap minggu',
            'is_active': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          await db.insert('payments', <String, Object?>{
            'cash_type_id': weeklyId,
          });
        },
      );
      await oldDb.close();

      final Database upgraded = await DBHelper.instance.database;
      final List<Map<String, Object?>> activeTypes = await upgraded.query(
        'cash_types',
        where: 'is_active = 1',
      );
      final List<Map<String, Object?>> weeklyTypes = await upgraded.query(
        'cash_types',
        where: 'code = ?',
        whereArgs: <Object?>['MINGGUAN'],
      );
      final Map<String, Object?> monthly = activeTypes.single;

      expect(monthly['name'], 'Kas Bulanan');
      expect(monthly['code'], 'BULANAN');
      expect(monthly['frequency'], 'bulanan');
      expect(monthly['amount'], 10000);
      expect(weeklyTypes, hasLength(1));
      expect(weeklyTypes.single['is_active'], 0);
      expect(await upgraded.query('payments'), hasLength(1));
    },
  );
}
