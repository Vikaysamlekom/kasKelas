import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BackupService.fileNameFor', () {
    test('menghasilkan nama backup dengan tanggal YYYY-MM-DD', () {
      final String name = BackupService.fileNameFor(DateTime(2026, 3, 9));
      expect(name, 'backup_kas_bintang_nusantara_2026-03-09.db');
    });
  });

  group('BackupService.uniqueBackupPath', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('backup_test');
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('memakai nama asli bila belum ada file', () async {
      final DateTime now = DateTime(2026, 3, 9, 10, 30, 15);
      final String target = p.join(dir.path, BackupService.fileNameFor(now));
      expect(await BackupService.uniqueBackupPath(dir, target, now), target);
    });

    test('tidak menimpa backup tanggal yang sama', () async {
      final DateTime now = DateTime(2026, 3, 9, 10, 30, 15);
      final String target = p.join(dir.path, BackupService.fileNameFor(now));
      await File(target).writeAsBytes(<int>[1, 2, 3]);

      final String hasil =
          await BackupService.uniqueBackupPath(dir, target, now);

      expect(hasil, isNot(target));
      expect(p.basename(hasil), 'backup_kas_bintang_nusantara_2026-03-09_103015.db');
      // File lama tetap utuh.
      expect(await File(target).readAsBytes(), <int>[1, 2, 3]);
    });

    test('menambah nomor urut bila suffix waktu juga bentrok', () async {
      final DateTime now = DateTime(2026, 3, 9, 10, 30, 15);
      final String base =
          p.basenameWithoutExtension(BackupService.fileNameFor(now));
      final String target = p.join(dir.path, BackupService.fileNameFor(now));
      await File(target).writeAsBytes(<int>[0]);
      await File(p.join(dir.path, '${base}_103015.db')).writeAsBytes(<int>[0]);

      final String hasil =
          await BackupService.uniqueBackupPath(dir, target, now);

      expect(p.basename(hasil), '${base}_103015_2.db');
    });
  });

  group('AutoBackupFrequency', () {
    test('mengubah nilai pref dan kembali', () {
      expect(AutoBackupFrequency.harian.prefValue, 'daily');
      expect(AutoBackupFrequency.mingguan.prefValue, 'weekly');
      expect(AutoBackupFrequency.mati.prefValue, 'off');
      expect(AutoBackupFrequency.fromPref('weekly'),
          AutoBackupFrequency.mingguan);
      expect(AutoBackupFrequency.fromPref(null), AutoBackupFrequency.mati);
    });
  });
}
