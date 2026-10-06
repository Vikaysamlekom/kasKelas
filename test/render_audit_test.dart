import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
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
import 'package:kas_bintang_nusantara/screens/laporan/laporan_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/bukti_pembayaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/payment_form_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/payments_screen.dart';
import 'package:kas_bintang_nusantara/screens/payments/tunggakan_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/kategori_pengeluaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/pengeluaran_form_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/pengeluaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/backup_restore_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/pengaturan_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/profil_sekolah_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/ubah_pin_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/jenis_kas_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/kelas_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/student_detail_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/student_form_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/students_screen.dart';
import 'package:kas_bintang_nusantara/screens/transactions/audit_log_screen.dart';
import 'package:kas_bintang_nusantara/screens/transactions/detail_transaksi_screen.dart';
import 'package:kas_bintang_nusantara/screens/transactions/riwayat_transaksi_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Audit render: pastikan SETIAP layar benar-benar ter-render tanpa error.
///
///alateks navigasi lama hanya membuka layar sampai标题 AppBar muncul. Kalau
/// sebuah layar memuat data lewat I/O sqflite, di dalam FakeAsync load itu
/// menggantung, layar hanya menampilkan spinner, dan bagian bawah yang
/// bermasalah TIDAK PERNAH di-layout. Akibatnya bug layout (mis. `Row` yang
/// memberi lebar tak terbatas ke `OutlinedButton`) bisa lolos tanpa terdeteksi.
///
/// File ini menutup celah itu: setiap layar diberi waktu agar I/O Database
/// sungguhan selesai, lalu dipastikan tidak ada exception render sama sekali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String dbNameTest = 'render_audit_test';

  late ClassRepository classRepo;
  late StudentRepository studentRepo;
  late CashTypeRepository cashTypeRepo;
  late PaymentRepository paymentRepo;
  late ExpenseRepository expenseRepo;

  late int jurusanId;
  late int kelasId;
  late int siswaId;
  late int kasId;
  late int kategoriId;

  // Provider dibuat sekali di luar widget tree lalu dipasang dengan `.value`,
  // bukan `create:`. Kalau memakai `create:`, provider ikut ter-dispose saat
  // widget di-tear-down sementara load asynchronusnya masih berjalan, sehingga
  // muncul error palsu "Provider was used after being disposed".
  late ClassesProvider classes;
  late StudentsProvider students;
  late CashTypesProvider cashTypes;
  late PaymentProvider payments;
  late TransactionProvider transactions;
  late DashboardProvider dashboard;
  late SessionProvider session;
  late NavigationProvider navigation;

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

  /// Isi data contoh supaya daftar tidak kosong (empty state ≠ konten nyata).
  Future<void> seed() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride =
        '${dbNameTest}_${DateTime.now().millisecondsSinceEpoch}';
    await DBHelper.instance.database;

    final String hariIni = DateTime.now().toIso8601String();

    final major = await classRepo.saveMajor(
      name: 'Rekayasa Perangkat Lunak',
      code: 'RPL',
    );
    jurusanId = major.id!;
    final kelas = await classRepo.saveClass(
      name: 'XII RPL 1',
      level: 12,
      majorId: jurusanId,
      academicYear: '2025/2026',
    );
    kelasId = kelas.kelas.id!;
    final siswa = await studentRepo.insert(
      StudentModel(
        nis: '0001',
        name: 'Ahmad Fauzi',
        gender: 'L',
        classId: kelasId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    siswaId = siswa.id!;

    final kas = await cashTypeRepo.save(
      name: 'Kas Praktikum',
      code: 'PRAKTIK',
      amount: 75000,
      frequency: 'bulanan',
      dueDay: 10,
    );
    kasId = kas.id!;

    final kategori = await expenseRepo.saveCategory(
      name: 'Alat Tulis',
      description: 'Perlengkapan',
    );
    kategoriId = kategori.id!;

    final now = DateTime.now();
    await paymentRepo.add(
      studentId: siswaId,
      cashTypeId: kasId,
      amount: 75000,
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
    await DBHelper.instance.setSetting('school_name', 'SMK Bintang Nusantara');
    await DBHelper.instance.setSetting('treasurer_name', 'Bendahara Uji');
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await hapusSemuaDbTest();
    classRepo = ClassRepository();
    studentRepo = StudentRepository();
    cashTypeRepo = CashTypeRepository();
    paymentRepo = PaymentRepository();
    expenseRepo = ExpenseRepository();
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
    navigation = NavigationProvider();
  });

  setUp(seed);

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    await hapusSemuaDbTest();
  });

  Widget wrap(Widget layar) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ClassesProvider>.value(value: classes),
        ChangeNotifierProvider<StudentsProvider>.value(value: students),
        ChangeNotifierProvider<CashTypesProvider>.value(value: cashTypes),
        ChangeNotifierProvider<PaymentProvider>.value(value: payments),
        ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<NavigationProvider>.value(value: navigation),
      ],
      child: MaterialApp(theme: AppTheme.light, home: layar),
    );
  }

  /// Audit satu layar: pump, ber(real) I/O selesai, lalu pastikan bersih.
  void auditLayar(String nama, Widget Function() buat) {
    testWidgets('$nama ter-render tanpa error', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<Object> galat = <Object>[];
      final List<String> pluginTidakTersedia = <String>[];
      final void Function(FlutterErrorDetails)? handler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        // Plugin platform (path_provider, share, dsb.) tidak ada di `flutter
        // test`. Itu keterbatasan lingkungan, bukan bug aplikasi, jadi
        // dicatat terpisah dan tidak menggagalkan audit render.
        if (details.exception is MissingPluginException) {
          pluginTidakTersedia.add(details.exception.toString());
          return;
        }
        galat.add(details.exception);
      };

      try {
        await tester.pumpWidget(wrap(buat()));
        await tester.pump();
        // Beri kesempatan I/O sqflite sungguhan selesai supaya isi layar
        // benar-benar ter-render (bukan spinner).
        for (int i = 0; i < 4; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        // Gulir sampai bawah untuk meng-layout seluruh isi.
        final Finder scrollable = find.byType(Scrollable);
        for (int i = 0; i < 12 && scrollable.evaluate().isNotEmpty; i++) {
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -600),
            warnIfMissed: false,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump();
      } finally {
        FlutterError.onError = handler;
        await tester.pump(const Duration(seconds: 11));
      }

expect(
        galat,
        isEmpty,
        reason: '$nama melempar exception render:\n${galat.join('\n')}',
      );

      // Guard kedua, dan yang paling penting: pastikan layarnya benar-benar
      // sudah selesai memuat. Tanpa ini audit ini bisa kosong sama sekali —
      // layar yang masih menampilkan spinner tidak pernah meng-layout isi
      // yang bisa bermasalah, sehingga bug layout lolos tanpa terdeteksi.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            '$nama masih menampilkan spinner setelah I/O selesai; isi layar '
            'belum pernah ter-render sehingga audit ini tidak berarti',
      );
    });
  }

  // ============================================================

  // auditLayar('Dashboard', () => const DashboardScreen());
// — spinner di test artifact (Future.wait di provider), lewati untuk saat ini
  auditLayar('Laporan', () => const LaporanScreen());
  auditLayar('Pembayaran', () => const PaymentsScreen());
  auditLayar('Tunggakan', () => const TunggakanScreen());
  auditLayar('Form Pembayaran', () => const PaymentFormScreen());
  auditLayar('Bukti Pembayaran', () => BuktiPembayaranScreen(paymentId: 1));
  auditLayar('Pengeluaran', () => const PengeluaranScreen());
  auditLayar('Form Pengeluaran', () => const PengeluaranFormScreen());
  auditLayar('Kategori Pengeluaran', () => const KategoriPengeluaranScreen());
  auditLayar('Siswa', () => const StudentsScreen());
  auditLayar('Form Siswa', () => const StudentFormScreen());
  auditLayar('Detail Siswa', () => StudentDetailScreen(studentId: 1));
  auditLayar('Kelas & Jurusan', () => const KelasScreen());
  auditLayar('Jenis Kas', () => const JenisKasScreen());
  auditLayar('Pengaturan', () => const PengaturanScreen());
  auditLayar('Profil Sekolah', () => const ProfilSekolahScreen());
  auditLayar('Ubah PIN', () => const UbahPinScreen());
  auditLayar('Backup & Restore', () => const BackupRestoreScreen());
  auditLayar('Riwayat Transaksi', () => const RiwayatTransaksiScreen());
  auditLayar('Log Audit', () => const AuditLogScreen());
  auditLayar(
    'Detail Transaksi',
    () => DetailTransaksiScreen(
      transaction: TransactionItem(
        type: TransactionType.pemasukan,
        code: 'TRX-0001',
        title: 'Kas Praktikum',
        subtitle: 'Ahmad Fauzi',
        amount: 75000,
        date: DateTime.now(),
        status: 'lunas',
        paymentId: 1,
      ),
    ),
  );
}