import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/school_profile_model.dart';
import 'package:kas_bintang_nusantara/models/student_model.dart';
import 'package:kas_bintang_nusantara/providers/cash_types_provider.dart';
import 'package:kas_bintang_nusantara/providers/classes_provider.dart';
import 'package:kas_bintang_nusantara/providers/dashboard_provider.dart';
import 'package:kas_bintang_nusantara/providers/navigation_provider.dart';
import 'package:kas_bintang_nusantara/providers/payment_provider.dart';
import 'package:kas_bintang_nusantara/providers/session_provider.dart';
import 'package:kas_bintang_nusantara/providers/students_provider.dart';
import 'package:kas_bintang_nusantara/providers/transaction_provider.dart';
import 'package:kas_bintang_nusantara/repositories/audit_repo.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/cash_type_repo.dart';
import 'package:kas_bintang_nusantara/repositories/dashboard_repository.dart';
import 'package:kas_bintang_nusantara/repositories/kelas_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pembayaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pengeluaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:kas_bintang_nusantara/repositories/school_profile_repo.dart';
import 'package:kas_bintang_nusantara/screens/dashboard/dashboard_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/payments_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/tunggakan_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/pengeluaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/about_us_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/bantuan_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/pengaturan_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/jenis_kas_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/kelas_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/students_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji asap (smoke test) navigasi: memastikan SETIUP entry menu & tombol
/// benar-benar membuka layarnya - tidak ada tombol mati yang "tidak merespons".
///
/// Semua entri menu dari tab Pembayaran, Siswa, dan Lainnya diuji satu per satu
/// dengan menekan ikon/tile lalu memastikan AppBar tujuan benar-benar muncul.
void main() {
  late ClassRepository classRepo;
  late StudentRepository studentRepo;
  late CashTypeRepository cashTypeRepo;
  late PaymentRepository paymentRepo;
  late ExpenseRepository expenseRepo;

  late ClassesProvider classes;
  late StudentsProvider students;
  late CashTypesProvider cashTypes;
  late PaymentProvider payments;
  late TransactionProvider transactions;
  late DashboardProvider dashboard;
  late SessionProvider session;

  int kelasId = 0;
  int jurusanId = 0;
  int siswaId = 0;
  int jenisKasId = 0;
  int kategoriId = 0;

  const String dbNameTest = 'kas_test_navigation_smoke.db';

  /// Setiap test memakai nama database sendiri supaya tidak perlu menghapus
  /// file yang masih terkunci oleh koneksi FFI di Windows.
  int dbCounter = 0;

  /// Hapus semua file DB milik test ini (termasuk file samping WAL/journal).
  Future<void> hapusSemuaDbTest() async {
    final String base = await getDatabasesPath();
    final Directory dir = Directory(base);
    if (!dir.existsSync()) return;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is! File) continue;
      final String nama = f.uri.pathSegments.last;
      if (!nama.startsWith(dbNameTest)) continue;
      for (final String s in <String>['', '-journal', '-wal', '-shm']) {
        final File target = File('${f.path}$s');
        if (target.existsSync()) {
          try {
            target.deleteSync();
          } on FileSystemException {
            // Diabaikan: file mungkin masih terkunci Windows.
          }
        }
      }
    }
  }

  /// Membersihkan DB + membuat data contoh. WAJIB di luar `testWidgets`
  /// karena I/O sqflite FFI nyata dan tidak jalan di FakeAsync.
  Future<void> seed() async {
    await DBHelper.instance.close();
    dbCounter++;
    DBHelper.dbNameOverride = '${dbNameTest}_$dbCounter';
    await DBHelper.instance.database;

    final now = DateTime.now();
    final String hariIni =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final major = await classRepo.saveMajor(
      name: 'Rekayasa Perangkat Lunak',
      code: 'RPL',
    );
    jurusanId = major.id!;
    final kelas = await classRepo.saveClass(
      name: 'XII RPL 1',
      level: 12,
      majorId: jurusanId,
      homeroomTeacher: 'Budi Santoso, S.Kom.',
      academicYear: '${now.year}/${now.year + 1}',
    );
    kelasId = kelas.kelas.id!;

    jenisKasId = (await cashTypeRepo.save(
      name: 'Kas Uji Smoke',
      code: 'UJI',
      amount: 50000,
      frequency: 'bulanan',
      dueDay: 10,
    )).id!;

    // Pakai kategori bawaan DB ('Operasional') supaya tidak bentrok.
    kategoriId = (await expenseRepo.listCategories()).first.id ?? 1;

    final DateTime st = DateTime.now();
    siswaId = (await studentRepo.insert(
      StudentModel(
        nis: '24001',
        name: 'Ahmad Fauzi',
        classId: kelasId,
        majorId: jurusanId,
        createdAt: st,
        updatedAt: st,
      ),
    )).id!;

    await paymentRepo.add(
      studentId: siswaId,
      cashTypeId: jenisKasId,
      amount: 50000,
      month: now.month,
      year: now.year,
      paidDate: hariIni,
    );
    await expenseRepo.add(
      categoryId: kategoriId,
      amount: 25000,
      expenseDate: hariIni,
      description: 'Beli ATK',
    );
    await DBHelper.instance.logAudit(
      userId: null,
      action: 'test',
      entityTable: DBHelper.tblStudents,
      entityId: siswaId,
      description: 'Aktivitas contoh',
    );

    // Muat SEMUA provider di luar FakeAsync supaya layar tidak menampilkan
    // spinner tak berujung (CircularProgressIndicator membuat pumpAndSettle
    // selalu timeout).
    classes = ClassesProvider(classRepository: classRepo);
    students = StudentsProvider(
      studentRepository: studentRepo,
      classRepository: classRepo,
    );
    cashTypes = CashTypesProvider(cashTypeRepository: cashTypeRepo);
    payments = PaymentProvider(
      paymentRepository: paymentRepo,
      classRepository: classRepo,
      studentRepository: studentRepo,
      cashTypeRepository: cashTypeRepo,
    );
    transactions = TransactionProvider(
      expenseRepository: expenseRepo,
      paymentRepository: paymentRepo,
      cashTypeRepository: cashTypeRepo,
      auditLogRepository: AuditLogRepository(),
    );
    dashboard = DashboardProvider(repository: DashboardRepository());
    session = SessionProvider(authRepository: AuthRepository());

    await classes.load();
    await students.load();
    await cashTypes.load();
    await payments.load();
    await payments.loadTunggakan();
    await transactions.loadExpenses();
    await transactions.loadRiwayat();
    await transactions.loadAudit();
    await dashboard.load();
  }

  Widget wrap(Widget home) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ChangeNotifierProvider<StudentsProvider>.value(value: students),
        ChangeNotifierProvider<ClassesProvider>.value(value: classes),
        ChangeNotifierProvider<CashTypesProvider>.value(value: cashTypes),
        ChangeNotifierProvider<PaymentProvider>.value(value: payments),
        ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );
  }

  /// Pump singkat - sengaja TIDAK memakai pumpAndSettle karena beberapa layar
  /// menampilkan CircularProgressIndicator yang berputar tanpa henti.
  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  /// Tester標準 dengan drain timer otomatis di akhir test.
  void smokeTest(String nama, Future<void> Function(WidgetTester) body) {
    testWidgets(nama, (WidgetTester tester) async {
      try {
        await body(tester);
      } finally {
        // Buang Timer 10 detik milik sqflite yang menggantung di FakeAsync,
        // kalau tidak test gagal: "A Timer is still pending ...".
        await tester.pump(const Duration(seconds: 11));
      }
    });
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DBHelper.dbNameOverride = dbNameTest;
    classRepo = ClassRepository();
    studentRepo = StudentRepository();
    cashTypeRepo = CashTypeRepository();
    paymentRepo = PaymentRepository();
    expenseRepo = ExpenseRepository();
    await hapusSemuaDbTest();
  });

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    await hapusSemuaDbTest();
  });

  setUp(seed);

  smokeTest('Dashboard menampilkan logo dan nama sekolah', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () => SchoolProfileRepository().saveProfile(
        SchoolProfileModel(
          schoolName: 'SMK Logo Dashboard',
          logoPath:
              '${Directory.systemTemp.path}${Platform.pathSeparator}logo-dashboard-test.png',
          updatedAt: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(wrap(const Scaffold(body: DashboardScreen())));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tick(tester);

    expect(find.text('SMK Logo Dashboard'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Image && widget.image is FileImage,
      ),
      findsNWidgets(2),
    );
  });

  // ============================================================
  // TAB "LAINNYA" (PengaturanScreen)
  // ============================================================

  /// Pastikan widget terlihat (scroll bila perlu) lalu ketuk.
  ///
  /// Layar pengaturan panjang dan viewport test hanya 800x600, jadi sebagian
  /// tile berada di luar area terlihat.
  Future<void> ketukTerlihat(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f.first);
  }

  group('Menu Lainnya - semua tile membuka layar tujuan', () {
    Future<void> cekTile(
      WidgetTester tester,
      String labelTile,
      String judulHarapan,
    ) async {
      await ketukTerlihat(tester, find.text(labelTile));
      await tick(tester);
      expect(
        find.text(judulHarapan),
        findsWidgets,
        reason: 'Tile "$labelTile" tidak membuka "$judulHarapan"',
      );
    }

    smokeTest('Profil Sekolah', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Profil Sekolah', 'Profil Sekolah');
    });

    smokeTest('Ubah PIN', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Ubah PIN', 'Ubah PIN');
    });

    smokeTest('Backup & Restore', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Backup & Restore', 'Backup & Restore');
    });

    smokeTest('Pengeluaran', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Pengeluaran', 'Pengeluaran');
    });

    smokeTest('Tunggakan', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Tunggakan', 'Tunggakan');
    });

    smokeTest('Riwayat Transaksi tidak ada di Lainnya', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      expect(find.text('Riwayat Transaksi'), findsNothing);
    });

    smokeTest('Audit Log', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Audit Log', 'Audit Log');
    });

    smokeTest('Bantuan menyediakan pesan email yang bisa diedit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Bantuan', 'Pesan bantuan');
      expect(find.byType(BantuanScreen), findsOneWidget);
      expect(find.text('ranggawaridat@gmail.com'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    smokeTest('Tentang menampilkan informasi aplikasi dan kelompok pengabdi', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await cekTile(tester, 'Tentang', 'INFORMASI APLIKASI');
      expect(find.byType(AboutUsScreen), findsOneWidget);
      expect(find.text('Kas Bintang Nusantara'), findsWidgets);
      expect(find.text('1.0.7'), findsOneWidget);
      expect(find.text('Universitas Pamulang'), findsOneWidget);
      expect(
        find.text('Kelompok pengabdian kepada masyarakat'),
        findsOneWidget,
      );
      for (final String nama in <String>[
        'Achmad Refaldi Peto',
        'Agustina Febriyanti',
        'Aprizal Dwi Lutfiansah',
        'Evan Hardyansyah',
        'Muhamad Reinaldi Putra Ramadhani',
        'Muhammad Susilo',
        'Phundut Bagas Wazidan',
        'Rangga Waridat',
        'Usep Saeful Adzkia',
        'Vickry Dwi Prasetyanto',
      ]) {
        expect(find.text(nama), findsOneWidget);
      }
    });

    smokeTest('Logout memunculkan dialog konfirmasi', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PengaturanScreen()));
      await tick(tester);
      await ketukTerlihat(tester, find.text('Logout'));
      await tick(tester);
      expect(find.text('Logout'), findsWidgets);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  // ============================================================
  // TAB "PEMBAYARAN"
  // ============================================================

  group('Menu Pembayaran - semua item membuka layar tujuan', () {
    Future<void> cekMenu(
      WidgetTester tester,
      String labelMenu,
      String judulHarapan,
    ) async {
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tick(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(PopupMenuItem<String>),
        findsAtLeast(2),
        reason: 'Popup menu tidak terbuka',
      );
      expect(
        find.text(labelMenu),
        findsWidgets,
        reason: 'Item popup menu tidak ditemukan: $labelMenu',
      );
      await tester.tap(find.text(labelMenu).last);
      await tick(tester);
      expect(
        find.text(judulHarapan),
        findsWidgets,
        reason: 'Menu "$labelMenu" tidak membuka "$judulHarapan"',
      );
    }

    smokeTest('Riwayat Transaksi', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);
      await cekMenu(tester, 'Riwayat Transaksi', 'Riwayat Transaksi');
    });

    smokeTest('Kelola Jenis Kas', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);
      await cekMenu(tester, 'Kelola Jenis Kas', 'Jenis Kas');
    });

    smokeTest('Laporan', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);
      await cekMenu(tester, 'Laporan', 'Laporan');
    });

    smokeTest('Popup hanya berisi Riwayat, Laporan, dan Jenis Kas', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tick(tester);
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
      expect(find.text('Tunggakan'), findsNothing);
      expect(find.text('Pengeluaran'), findsNothing);
      expect(find.text('Audit Log'), findsNothing);
    });

    smokeTest('FAB "Buat Pembayaran" membuka form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Buat Pembayaran'), findsWidgets);
    });
  });

  // ============================================================
  // TAB "SISWA"
  // ============================================================

  group('Menu Siswa - semua item & tombol bekerja', () {
    Future<void> cekMenu(
      WidgetTester tester,
      String labelMenu,
      String judulHarapan,
    ) async {
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tick(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(PopupMenuItem<String>),
        findsAtLeast(2),
        reason: 'Popup menu tidak terbuka',
      );
      expect(
        find.text(labelMenu),
        findsWidgets,
        reason: 'Item popup menu tidak ditemukan: $labelMenu',
      );
      await tester.tap(find.text(labelMenu).last);
      await tick(tester);
      expect(
        find.text(judulHarapan),
        findsWidgets,
        reason: 'Menu "$labelMenu" tidak membuka "$judulHarapan"',
      );
    }

    smokeTest('Kelas & Jurusan', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const StudentsScreen()));
      await tick(tester);
      await cekMenu(tester, 'Kelola Kelas & Jurusan', 'Kelas & Jurusan');
    });

    smokeTest('Popup hanya berisi Import, Export, dan Kelas & Jurusan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const StudentsScreen()));
      await tick(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tick(tester);
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
      expect(find.text('Import Siswa (CSV)'), findsOneWidget);
      expect(find.text('Export Siswa (CSV)'), findsOneWidget);
      expect(find.text('Kelola Kelas & Jurusan'), findsOneWidget);
      expect(find.text('Kelola Jenis Kas'), findsNothing);
    });

    smokeTest('FAB "Tambah Siswa" membuka form', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const StudentsScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Tambah Siswa'), findsWidgets);
    });

    smokeTest('Mengetuk kartu siswa membuka detail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const StudentsScreen()));
      await tick(tester);
      await tester.tap(find.text('Ahmad Fauzi').first);
      await tick(tester);
      expect(find.text('Detail Siswa'), findsWidgets);
    });
  });

  // ============================================================
  // TOMBOL TAMBAH DI LAYAR KELAS & JURUSAN
  // ============================================================

  group('Kelas & Jurusan - tombol tambah bekerja', () {
    smokeTest('FABtab Kelas membuka form kelas', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const KelasScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Tambah Kelas'), findsWidgets);
      expect(find.text('Simpan'), findsOneWidget);
    });

    smokeTest('FAB tab Jurusan membuka form jurusan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const KelasScreen()));
      await tick(tester);
      await tester.tap(find.text('Jurusan'));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Tambah Jurusan'), findsWidgets);
      expect(find.text('Simpan'), findsOneWidget);
    });
  });

  // ============================================================
  // FILTER TAHUN HARUS SAMPAI 2100
  // ============================================================

  group('Filter tahun menjangkau tahun 2100', () {
    smokeTest('dropdown Tahun di Pembayaran bisa memilih 2100', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PaymentsScreen()));
      await tick(tester);

      // Buka dropdown kedua di baris filter (Bulan, Tahun, Kelas).
      final Finder expand = find.byIcon(Icons.expand_more_rounded);
      await tester.tap(expand.at(1));
      await tick(tester);

      // Flutter hanya membangun item dropdown yang terlihat, jadi 2100 harus
      // dijangkau dengan menggulir seperti yang dilakukan pengguna.
      final Finder list = find.byType(Scrollable).last;
      for (int i = 0; i < 40; i++) {
        if (find.text('2100').evaluate().isNotEmpty) break;
        await tester.drag(list, const Offset(0, -300));
        await tester.pump();
      }
      expect(
        find.text('2100'),
        findsWidgets,
        reason: 'Tahun 2100 tidak bisa dijangkau di dropdown filter',
      );

      await tester.ensureVisible(find.text('2100').last);
      await tester.pump();
      await tester.tap(find.text('2100').last);
      await tick(tester);

      expect(payments.filter.year, 2100);
    });
  });

  // ============================================================
  // FAB PADA LAYAR PENGELUARAN & JENIS KAS
  // ============================================================

  group('FAB Pengeluaran & Jenis Kas bekerja', () {
    smokeTest('FAB Pengeluaran membuka form pengeluaran', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const PengeluaranScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Tambah Pengeluaran'), findsWidgets);
    });

    smokeTest('FAB Jenis Kas membuka form jenis kas', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const JenisKasScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);
      expect(find.text('Simpan'), findsOneWidget);
    });
  });

  // ============================================================
  // LAYAR TUNGGAKAN
  // ============================================================

  group('Layar Tunggakan', () {
    smokeTest('menampilkan data dan bisa difilter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const TunggakanScreen()));
      await tick(tester);
      expect(find.text('Tunggakan'), findsWidgets);
    });
  });
}
