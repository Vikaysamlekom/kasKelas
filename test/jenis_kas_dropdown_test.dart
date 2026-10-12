import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/student_model.dart';
import 'package:kas_bintang_nusantara/providers/cash_types_provider.dart';
import 'package:kas_bintang_nusantara/providers/classes_provider.dart';
import 'package:kas_bintang_nusantara/providers/payment_provider.dart';
import 'package:kas_bintang_nusantara/providers/session_provider.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/cash_type_repo.dart';
import 'package:kas_bintang_nusantara/repositories/kelas_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pembayaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:kas_bintang_nusantara/screens/payments/payment_form_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regresi: "Jenis kas tidak bisa memilih apapun" saat input pembayaran.
///
/// Akar masalahnya: `CashTypesProvider.load()` tidak pernah dipanggil di
/// `PaymentFormScreen`, sehingga `_cashTypes` tetap kosong walaupun database
/// sudah berisi 3 jenis kas default. Dropdown jadi kosong dan tidak ada yang
/// bisa dipilih.
///
/// Test ini sengaja memakai provider KOSONG (persis kondisi sebelum fix) lalu
/// memverifikasi form memuat sendiri jenis kas dan bisa dipilih.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String dbNameTest = 'jenis_kas_dropdown_test';

  late ClassRepository classRepo;
  late StudentRepository studentRepo;
  late CashTypeRepository cashTypeRepo;
  late PaymentRepository paymentRepo;

  Future<void> hapusSemuaDbTest() async {
    final String base = await getDatabasesPath();
    final Directory dir = Directory(base);
    if (!dir.existsSync()) return;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is! File) continue;
      if (!p.basename(f.path).startsWith(dbNameTest)) continue;
      try {
        f.deleteSync();
      } on FileSystemException {
        // Diabaikan: file mungkin masih terkunci Windows.
      }
    }
  }

  Future<void> seed() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride =
        '${dbNameTest}_${DateTime.now().millisecondsSinceEpoch}';
    await DBHelper.instance.database;

    final major = await classRepo.saveMajor(
      name: 'Rekayasa Perangkat Lunak',
      code: 'RPL',
    );
    final kelas = await classRepo.saveClass(
      name: 'XII RPL 1',
      level: 12,
      majorId: major.id!,
      academicYear: '2025/2026',
    );
    await studentRepo.insert(
      StudentModel(
        nis: '0001',
        name: 'Ahmad Fauzi',
        gender: 'L',
        classId: kelas.kelas.id!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await hapusSemuaDbTest();
    classRepo = ClassRepository();
    studentRepo = StudentRepository();
    cashTypeRepo = CashTypeRepository();
    paymentRepo = PaymentRepository();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(seed);

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    await hapusSemuaDbTest();
  });

  Widget wrap(Widget layar, CashTypesProvider cashTypes) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CashTypesProvider>.value(value: cashTypes),
        ChangeNotifierProvider<PaymentProvider>(
          create: (_) => PaymentProvider(
            paymentRepository: paymentRepo,
            classRepository: classRepo,
            studentRepository: studentRepo,
            cashTypeRepository: cashTypeRepo,
          ),
        ),
        ChangeNotifierProvider<ClassesProvider>(
          create: (_) => ClassesProvider(classRepository: classRepo),
        ),
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(authRepository: AuthRepository()),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: layar),
    );
  }

  /// Biarkan post-frame callback + I/O sqflite selesai.
  Future<void> diamkan(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('dropdown Jenis Kas terisi dari database dan bisa dipilih', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Kondisi SEBELUM fix: provider benar-benar kosong, meski DB sudah berisi
    // 3 jenis kas default hasil seeding.
    final CashTypesProvider kosong = CashTypesProvider(
      cashTypeRepository: cashTypeRepo,
    );
    expect(
      kosong.cashTypes,
      isEmpty,
      reason: 'provider harus mulai kosong agar test benar-benar menguji fix',
    );

    await tester.pumpWidget(wrap(const PaymentFormScreen(), kosong));
    await tester.pump();
    await diamkan(tester);

    // 1. Form harus memanggil load() sendiri sehingga daftar terisi.
    expect(
      kosong.cashTypes,
      isNotEmpty,
      reason:
          'CashTypesProvider tidak dimuat oleh PaymentFormScreen sehingga '
          'dropdown Jenis Kas kosong dan tidak ada yang bisa dipilih',
    );
    expect(
      kosong.cashTypes.any((c) => c.name == 'Kas Bulanan'),
      isTrue,
      reason: 'Jenis kas bawaan "Kas Bulanan" harus termuat',
    );

    // 2. Dropdown harus bisa dibuka dan menampilkan isi.
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Item dropdown menampilkan "Nama · Rp nominal", jadi pakai textContaining.
    expect(find.textContaining('Kas Tahunan'), findsWidgets);
    expect(find.textContaining('Kas Sosial'), findsWidgets);

    // 3. Pilih salah satu jenis kas.
    await tester.tap(find.textContaining('Kas Bulanan').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 4. Tekan simpan: validasi "Jenis kas wajib dipilih" harus tidak muncul.
    await tester.tap(find.text('Simpan Pembayaran'));
    await tester.pump();
    await diamkan(tester);

    expect(
      find.text('Jenis kas wajib dipilih'),
      findsNothing,
      reason: 'dropdown Jenis kas tidak benar-benar terisi setelah dipilih',
    );
  });
}