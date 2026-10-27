import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/app_error.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/student_model.dart';
import 'package:kas_bintang_nusantara/providers/classes_provider.dart';
import 'package:kas_bintang_nusantara/providers/session_provider.dart';
import 'package:kas_bintang_nusantara/providers/students_provider.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/kelas_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:kas_bintang_nusantara/screens/students/student_form_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji widget form siswa dengan fokus pada kelas yang bersifat opsional.
///
/// Menguji regresi yang dilaporkan pengguna: dropdown kelas tampak kosong /
/// tidak bisa dipilih pada mode tambah maupun ubah.
void main() {
  late ClassRepository classRepo;
  late StudentRepository studentRepo;
  late AuthRepository authRepo;
  late ClassesProvider classesProvider;
  late int kelasAktifId;
  late int kelasNonaktifId;

  /// Nama file DB khusus file test ini supaya tidak bentrok dengan
  /// db_offline_test.dart yang juga memakai SQLite FFI.
  const String dbNameTest = 'kas_test_student_form.db';

  /// Siapkan database bersih. WAJIB dipanggil dari setUp (luar testWidgets)
  /// karena I/O sqflite FFI bersifat nyata dan tidak berjalan di FakeAsync.
  Future<void> resetDb({required bool denganKelas}) async {
    await DBHelper.instance.close();
    final String base = await getDatabasesPath();
    final Directory dir = Directory(base);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final File dbFile = File(p.join(base, dbNameTest));
    if (dbFile.existsSync()) dbFile.deleteSync();
    // Hanya file samping milik database test ini.
    for (final String suffix in <String>['-journal', '-wal', '-shm']) {
      final File sidecar = File('${dbFile.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }

    await DBHelper.instance.database;
    kelasAktifId = 0;
    kelasNonaktifId = 0;
    if (!denganKelas) return;

    final String now = DateTime.now().toIso8601String();
    kelasAktifId = await DBHelper.instance.insert(DBHelper.tblClasses, <String, Object?>{
      'name': 'XII RPL 1',
      'level': 12,
      'academic_year': '2026/2027',
      'is_active': 1,
      'created_at': now,
    });
    kelasNonaktifId = await DBHelper.instance.insert(DBHelper.tblClasses, <String, Object?>{
      'name': 'XI RPL 1',
      'level': 11,
      'academic_year': '2026/2027',
      'is_active': 0,
      'created_at': now,
    });
  }

  Widget wrapForm(Widget child) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ClassesProvider>.value(value: classesProvider),
        ChangeNotifierProvider<StudentsProvider>(
          create: (_) => StudentsProvider(
            studentRepository: studentRepo,
            classRepository: classRepo,
          ),
        ),
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(authRepository: authRepo),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DBHelper.dbNameOverride = dbNameTest;
    classRepo = ClassRepository();
    studentRepo = StudentRepository();
    authRepo = AuthRepository();
  });

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
  });

  group('Dropdown kelas - kelas tersedia', () {
    setUp(() async {
      await resetDb(denganKelas: true);
      classesProvider = ClassesProvider(classRepository: classRepo);
      await classesProvider.load();
    });

    testWidgets('menampilkan kelas yang sudah dimuat', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kelas (opsional)'), findsOneWidget);
      // Fixture benar: satu kelas aktif, satu nonaktif.
      expect(classesProvider.classes.length, 2);
      expect(
        classesProvider.classes.any((ClassWithMeta c) => c.kelas.id == kelasAktifId && c.kelas.isActive),
        isTrue,
      );
      // Belum ada kelas terpilih pada mode tambah, jadi field menampilkan label.
      expect(find.text('XII RPL 1'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();

      expect(find.text('XII RPL 1'), findsOneWidget);
      // Kelas nonaktif tidak boleh muncul pada mode tambah.
      expect(find.text('XI RPL 1 (nonaktif)'), findsNothing);
    });

    testWidgets('kelas bisa dipilih lewat dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('XII RPL 1').last);
      await tester.pumpAndSettle();

      // Nilai terpilih tampil di field.
      expect(find.text('XII RPL 1'), findsOneWidget);
      expect(find.text('Kelas wajib dipilih'), findsNothing);
    });

    testWidgets('kelas milik siswa tetap tampil walau kelasnya nonaktif', (
      WidgetTester tester,
    ) async {
      final StudentModel siswa = StudentModel(
        id: 99,
        nis: '1001',
        name: 'Ahmad Fauzi',
        classId: kelasNonaktifId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(wrapForm(StudentFormScreen(student: siswa)));
      await tester.pumpAndSettle();

      // Ini kondisi yang sebelumnya membuat dropdown tampil kosong.
      expect(find.text('XI RPL 1 (nonaktif)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Bisa diganti ke kelas aktif.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('XII RPL 1').last);
      await tester.pumpAndSettle();

      expect(find.text('XII RPL 1'), findsOneWidget);
    });

    testWidgets('form memanggil load() sendiri saat provider masih kosong', (
      WidgetTester tester,
    ) async {
      classesProvider = ClassesProvider(classRepository: classRepo);
      expect(classesProvider.classes, isEmpty);

      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      // Biarkan I/O database nyata selesai di luar zona waktu palsu.
      await tester.runAsync(() async {
        for (int i = 0; i < 60 && classesProvider.classes.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      expect(classesProvider.classes, isNotEmpty);
      expect(classesProvider.hasLoaded, isTrue);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('XII RPL 1'), findsOneWidget);
    });
  });

  group('Dropdown kelas - belum ada kelas', () {
    setUp(() async {
      await resetDb(denganKelas: false);
      classesProvider = ClassesProvider(classRepository: classRepo);
      await classesProvider.load();
    });

    testWidgets('empty state menjelaskan bahwa kelas opsional', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada kelas'), findsOneWidget);
      expect(
        find.text(
          'Kelas bersifat opsional. Siswa tetap bisa disimpan tanpa kelas.',
        ),
        findsOneWidget,
      );
      expect(find.text('Buat Kelas Sekarang'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    });

    test('siswa dapat disimpan tanpa class_id', () async {
      final DateTime now = DateTime.now();
      final StudentModel siswa = await studentRepo.insert(
        StudentModel(
          nis: '2001',
          name: 'Siswa Tanpa Kelas',
          classId: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(siswa.nis, '2001');
      expect(siswa.classId, isNull);
    });

    testWidgets('tombol buat kelas membuka layar Kelas & Jurusan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buat Kelas Sekarang'));
      await tester.pumpAndSettle();

      // Layar manage harus terbuka-
      expect(find.text('Kelas & Jurusan'), findsOneWidget);
      expect(find.text('Belum ada kelas'), findsOneWidget);

      // -dan WAJIB punya jalan membuat kelas (regresi: tidak ada tombol +).
      expect(
        find.widgetWithText(FloatingActionButton, 'Tambah Kelas'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FloatingActionButton, 'Tambah Jurusan'),
        findsNothing,
      );
    });

    testWidgets('FAB tab Jurusan membuka form tambah jurusan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Kelas Sekarang'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jurusan'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FloatingActionButton, 'Tambah Jurusan'),
        findsOneWidget,
      );
      expect(find.text('Belum ada jurusan'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Buat Jurusan'),
        findsOneWidget,
      );
    });

    testWidgets('form kelas punya field lengkap + jalan buat jurusan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapForm(const StudentFormScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Kelas Sekarang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Kelas'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Kelas'), findsWidgets);
      expect(find.text('Nama Kelas *'), findsOneWidget);
      expect(find.text('Tingkat *'), findsOneWidget);
      // 'Jurusan' muncul dua kali: label tab + label dropdown.
      expect(find.text('Jurusan'), findsNWidgets(2));
      expect(find.text('Wali Kelas'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Simpan'), findsOneWidget);
      // Jalan membuat jurusan tanpa keluar dari form.
      expect(
        find.text('Belum ada jurusan? Buat sekarang'),
        findsOneWidget,
      );
    });
  });

  _testPenyimpanan(resetDb);
}

/// Penyimpanan kelas & jurusan diuji di sini (bukan lewat widget) karena
/// I/O SQLite bersifat nyata dan tidak selesai di dalam zona FakeAsync.
void _testPenyimpanan(
  Future<void> Function({required bool denganKelas}) resetDb,
) {
  group('Penyimpanan kelas & jurusan', () {
    late ClassesProvider provider;
    late ClassRepository repo;

    setUp(() async {
      await resetDb(denganKelas: false);
      repo = ClassRepository();
      provider = ClassesProvider(classRepository: repo);
    });

    test('provider bisa membuat jurusan lalu kelas', () async {
      final int majorId = await provider.saveMajor(
        name: 'Rekayasa Perangkat Lunak',
        code: 'rpl',
      );
      expect(majorId, greaterThan(0));

      final int classId = await provider.saveClass(
        name: 'XII RPL 1',
        level: 12,
        majorId: majorId,
      );
      expect(classId, greaterThan(0));

      expect(provider.majors.length, 1);
      expect(provider.majors.first.major.code, 'RPL');
      expect(provider.classes.length, 1);
      expect(provider.classes.first.majorName, 'Rekayasa Perangkat Lunak');
      expect(provider.classes.first.kelas.level, 12);
    });

    test('kelas dan jurusan muncul di form siswa setelah load ulang', () async {
      await provider.saveMajor(name: 'Teknik Komputer', code: 'TK');
      await provider.saveClass(name: 'X TK 2', level: 10);
      await provider.load();

      expect(provider.classes.length, 1);
      expect(provider.classes.first.kelas.name, 'X TK 2');
    });

    test('cek duplikat nama kelas dan kode jurusan', () async {
      await provider.saveClass(name: 'XII RPL 1', level: 12);
      expect(
        await repo.classNameExists('XII RPL 1'),
        isTrue,
        reason: 'form kelas memakai ini untuk menolak nama ganda',
      );
      expect(await repo.classNameExists('XII RPL 2'), isFalse);

      await provider.saveMajor(name: 'Rekayasa Perangkat Lunak', code: 'RPL');
      expect(await repo.majorCodeExists('RPL'), isTrue);
      expect(await repo.majorCodeExists('TK'), isFalse);
    });

    test('kelas kedua dengan nama sama ditolak database + pesan ramah', () async {
      await provider.saveClass(name: 'XII RPL 1', level: 12);
      await expectLater(
        provider.saveClass(name: 'XII RPL 1', level: 11),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            contains('duplikat'),
          ),
        ),
        reason: 'kolom name UNIQUE; form sudah mencegahnya lebih dulu',
      );
    });
  });
}
