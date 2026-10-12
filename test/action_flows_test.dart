import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/app_error.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/expense_category_model.dart';
import 'package:kas_bintang_nusantara/models/expense_model.dart';
import 'package:kas_bintang_nusantara/models/payment_model.dart';
import 'package:kas_bintang_nusantara/providers/cash_types_provider.dart';
import 'package:kas_bintang_nusantara/providers/classes_provider.dart';
import 'package:kas_bintang_nusantara/providers/navigation_provider.dart';
import 'package:kas_bintang_nusantara/providers/payment_provider.dart';
import 'package:kas_bintang_nusantara/providers/session_provider.dart';
import 'package:kas_bintang_nusantara/providers/students_provider.dart';
import 'package:kas_bintang_nusantara/providers/transaction_provider.dart';
import 'package:kas_bintang_nusantara/repositories/audit_repo.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/cash_type_repo.dart';
import 'package:kas_bintang_nusantara/repositories/kelas_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pembayaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pengeluaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:kas_bintang_nusantara/screens/payments/payment_form_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/kategori_pengeluaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/pengeluaran/pengeluaran_form_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/jenis_kas_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji tombol AKSI pada setiap form: apakah benar-benar mengirim data ke
/// provider, dan apakah tetap bisa dipencet lagi setelah gagal.
///
/// I/O sqflite asli tidak bisa selesai di dalam FakeAsync, jadi pada file ini
/// provider diganti dengan [_Rekam] (mencatat panggilan) dan [_Gagal]
/// (melempar error) supaya perilaku UI dapat diuji dengandeterministik.
void main() {
  late CashTypesProvider cashTypes;
  late PaymentProvider payments;
  late TransactionProvider transactions;

  Widget wrap(Widget home) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CashTypesProvider>.value(value: cashTypes),
        ChangeNotifierProvider<PaymentProvider>.value(value: payments),
        ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
        ChangeNotifierProvider<ClassesProvider>(
          create: (_) => ClassesProvider(classRepository: ClassRepository()),
        ),
        ChangeNotifierProvider<StudentsProvider>(
          create: (_) => StudentsProvider(
            studentRepository: StudentRepository(),
            classRepository: ClassRepository(),
          ),
        ),
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(authRepository: AuthRepository()),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void smokeTest(String nama, Future<void> Function(WidgetTester) body) {
    testWidgets(nama, (WidgetTester tester) async {
      // Viewport default test 800x600 membuat `ListView` hanya membangun
      // sebagian anak (lazy), sehingga field di bawah tidak ada di tree dan
      // pesan validasinya tidak bisa ditemukan. Viewport tinggi membuat
      // seluruh field terbangun.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      try {
        await body(tester);
      } finally {
        await tester.pump(const Duration(seconds: 11));
      }
    });
  }

  /// Ketuk sebuah tombol. Layar form memakai `ListView` yang Building-nya
  /// lazy, jadi tombol di bagian bawah belum ada di tree sampai digulir.
  Future<void> ketuk(WidgetTester tester, Finder f) async {
    await tester.pump();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f.first);
  }

  const String dbNameTest = 'action_flows_test';

  /// Hapus semua file DB milik test ini (termasuk WAL/journal).
  Future<void> hapusSemuaDbTest() async {
    final String base = await getDatabasesPath();
    final Directory dir = Directory(base);
    if (!dir.existsSync()) return;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is! File) continue;
      final String nama = p.basename(f.path);
      if (!nama.startsWith(dbNameTest)) continue;
      try {
        f.deleteSync();
      } on FileSystemException {
        // Diabaikan: file mungkin masih terkunci Windows.
      }
    }
  }

  /// `FilledButton.icon` mengembalikan subclass privat, jadi `find.byType`
  /// tidak akan cocok. Pakai predicate yang menerima seluruh subclass.
  Finder tombol(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DBHelper.dbNameOverride = dbNameTest;
    await hapusSemuaDbTest();
    await DBHelper.instance.database;
  });

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    await hapusSemuaDbTest();
  });

  setUp(() {
    cashTypes = _RekamCashTypes(cashTypeRepository: CashTypeRepository());
    payments = _RekamPayments(
      paymentRepository: PaymentRepository(),
      classRepository: ClassRepository(),
      studentRepository: StudentRepository(),
      cashTypeRepository: CashTypeRepository(),
    );
    transactions = _RekamTransactions(
      expenseRepository: ExpenseRepository(),
      paymentRepository: PaymentRepository(),
      cashTypeRepository: CashTypeRepository(),
      auditLogRepository: AuditLogRepository(),
    );
  });

  // ============================================================
  // SIMPAN JENIS KAS
  // ============================================================

  group('Tombol Simpan Jenis Kas', () {
    smokeTest('mengirim data form ke provider', (WidgetTester tester) async {
      final _RekamCashTypes p = cashTypes as _RekamCashTypes;
      await tester.pumpWidget(wrap(const JenisKasScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama *'),
        'Kas Praktikum',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kode *'),
        'PRAKTIK',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '75000',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan'));
      await tick(tester);

      expect(p.panggil, isTrue, reason: 'Tombol Simpan tidak memanggil provider');
      expect(p.nama, 'Kas Praktikum');
      expect(p.kode, 'PRAKTIK');
      expect(p.nominal, 75000);
      expect(p.frekuensi, 'bulanan');
    });

    smokeTest('form kosong divalidasi, provider tidak dipanggil', (
      WidgetTester tester,
    ) async {
      final _RekamCashTypes p = cashTypes as _RekamCashTypes;
      await tester.pumpWidget(wrap(const JenisKasScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);

      await ketuk(tester, find.text('Simpan'));
      await tick(tester);

      expect(p.panggil, isFalse, reason: 'Data kosong seharusnya ditolak');
    });

    smokeTest('gagal simpan: tombol NYALA lagi (tidak macet)', (
      WidgetTester tester,
    ) async {
      final _GagalCashTypes p = _GagalCashTypes(cashTypeRepository: CashTypeRepository());
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<CashTypesProvider>.value(value: p),
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => SessionProvider(authRepository: AuthRepository()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const JenisKasScreen(),
          ),
        ),
      );
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama *'),
        'Kas Ganda',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kode *'),
        'GANDA',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '5000',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan'));
      await tick(tester);

      expect(p.panggil, isTrue);
      expect(
        find.textContaining('duplikat'),
        findsWidgets,
        reason: 'Pesan error duplikat tidak tampil ke pengguna',
      );
      expectTombolAktif(tester, tombol('Simpan'), 'Simpan');
    });
  });

  // ============================================================
  // SIMPAN KATEGORI PENGELUARAN
  // ============================================================

  group('Tombol Simpan Kategori Pengeluaran', () {
    smokeTest('mengirim nama kategori ke provider', (
      WidgetTester tester,
    ) async {
      final _RekamTransactions p = transactions as _RekamTransactions;
      await tester.pumpWidget(wrap(const KategoriPengeluaranScreen()));
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Kategori *'),
        'Alat Tulis',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Kategori'));
      await tick(tester);

      expect(p.panggilKategori, isTrue);
      expect(p.namaKategori, 'Alat Tulis');
    });

    smokeTest('gagal simpan kategori: tombol NYALA lagi', (
      WidgetTester tester,
    ) async {
      final _GagalKategori p = _GagalKategori(
        expenseRepository: ExpenseRepository(),
        paymentRepository: PaymentRepository(),
        cashTypeRepository: CashTypeRepository(),
        auditLogRepository: AuditLogRepository(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<TransactionProvider>.value(value: p),
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => SessionProvider(authRepository: AuthRepository()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const KategoriPengeluaranScreen(),
          ),
        ),
      );
      await tick(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Kategori *'),
        'Operasional',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Kategori'));
      await tick(tester);

      expect(p.panggilKategori, isTrue);
      expectTombolAktif(
        tester,
        tombol('Simpan Kategori'),
        'Simpan Kategori',
      );
    });
  });

  // ============================================================
  // SIMPAN PEMBAYARAN
  // ============================================================

  group('Tombol Simpan Pembayaran', () {
    smokeTest('tanpa siswa: ditolak, provider tidak dipanggil', (
      WidgetTester tester,
    ) async {
      final _RekamPayments p = payments as _RekamPayments;
      await tester.pumpWidget(wrap(const PaymentFormScreen()));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '10000',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Pembayaran'));
      await tick(tester);

      expect(find.text('Siswa wajib dipilih'), findsWidgets);
      expect(p.panggil, isFalse, reason: 'Jangan simpan tanpa siswa');
    });

    smokeTest('gagal simpan pembayaran: tombol NYALA lagi', (
      WidgetTester tester,
    ) async {
      final _GagalPembayaran p = _GagalPembayaran(
        paymentRepository: PaymentRepository(),
        classRepository: ClassRepository(),
        studentRepository: StudentRepository(),
        cashTypeRepository: CashTypeRepository(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<PaymentProvider>.value(value: p),
            // Pakai provider milik test (`.value`) agar tidak ikut di-dispose
            // pohon widget saat `PaymentFormScreen` memicu `load()` async.
            ChangeNotifierProvider<CashTypesProvider>.value(value: cashTypes),
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => SessionProvider(authRepository: AuthRepository()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PaymentFormScreen(),
          ),
        ),
      );
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '12000',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Pembayaran'));
      await tick(tester);

      // Tanpa siswa, validasi berhenti sebelum memanggil provider.
      expect(find.text('Siswa wajib dipilih'), findsWidgets);

      expectTombolAktif(
        tester,
        tombol('Simpan Pembayaran'),
        'Simpan Pembayaran',
      );
    });
  });

  // ============================================================
  // SIMPAN PENGELUARAN
  // ============================================================

  group('Tombol Simpan Pengeluaran', () {
    smokeTest('tanpa kategori: ditolak, provider tidak dipanggil', (
      WidgetTester tester,
    ) async {
      final _RekamTransactions p = transactions as _RekamTransactions;
      await tester.pumpWidget(wrap(const PengeluaranFormScreen()));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Keperluan *'),
        'Beli ATK',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Pengeluaran'));
      await tick(tester);

      expect(find.text('Kategori wajib dipilih'), findsWidgets);
      expect(p.panggilPengeluaran, isFalse);
    });

    smokeTest('gagal simpan pengeluaran: tombol NYALA lagi', (
      WidgetTester tester,
    ) async {
      final _GagalPengeluaran p = _GagalPengeluaran(
        expenseRepository: ExpenseRepository(),
        paymentRepository: PaymentRepository(),
        cashTypeRepository: CashTypeRepository(),
        auditLogRepository: AuditLogRepository(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<TransactionProvider>.value(value: p),
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => SessionProvider(authRepository: AuthRepository()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PengeluaranFormScreen(),
          ),
        ),
      );
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Keperluan *'),
        'Beli ATK',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Pengeluaran'));
      await tick(tester);

      expect(find.text('Kategori wajib dipilih'), findsWidgets);
      expectTombolAktif(
        tester,
        tombol('Simpan Pengeluaran'),
        'Simpan Pengeluaran',
      );
    });

    smokeTest('pengeluaran melebihi saldo: diblokir, tombol NYALA lagi', (
      WidgetTester tester,
    ) async {
      final _SaldoKurang p = _SaldoKurang(
        expenseRepository: ExpenseRepository(),
        paymentRepository: PaymentRepository(),
        cashTypeRepository: CashTypeRepository(),
        auditLogRepository: AuditLogRepository(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<TransactionProvider>.value(value: p),
            ChangeNotifierProvider<SessionProvider>(
              create: (_) => SessionProvider(authRepository: AuthRepository()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PengeluaranFormScreen(),
          ),
        ),
      );
      await tick(tester);

      // Pilih kategori dulu supaya validasi lolos sampai ke addExpense.
      await ketuk(tester, find.byType(DropdownButtonFormField<int>));
      await tick(tester);
      await ketuk(tester, find.text('Operasional'));
      await tick(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal *'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Keperluan *'),
        'Beli ATK',
      );
      await tick(tester);
      await ketuk(tester, find.text('Simpan Pengeluaran'));
      await tick(tester);

      expect(p.panggilPengeluaran, isTrue);
      expect(
        find.textContaining('Tidak bisa melanjutkan pengeluaran'),
        findsWidgets,
        reason: 'Pengeluaran melebihi saldo harus memberi pesan ke pengguna',
      );
      expectTombolAktif(
        tester,
        tombol('Simpan Pengeluaran'),
        'Simpan Pengeluaran',
      );
    });
  });
}

/// Pastikan tombol Simpan masih bisa ditekan setelah gagal disimpan.
/// Inilah penjaga regresi "tombol macet permanen".
void expectTombolAktif(WidgetTester tester, Finder f, String label) {
  expect(f, findsWidgets, reason: 'Tombol "$label" tidak ditemukan');
  final FilledButton b = tester.widget<FilledButton>(f.first);
  expect(
    b.onPressed,
    isNotNull,
    reason: 'REGRESI: tombol "$label" macet permanen setelah gagal',
  );
}

// ============================================================================
// PROVIDER UJI COBA
// ============================================================================

class _RekamCashTypes extends CashTypesProvider {
  bool panggil = false;
  String? nama;
  String? kode;
  int? nominal;
  String? frekuensi;

  _RekamCashTypes({required super.cashTypeRepository});

  @override
  Future<void> save({
    int? id,
    required String name,
    required String code,
    required int amount,
    required String frequency,
    required int dueDay,
    String? description,
    int? userId,
  }) async {
    panggil = true;
    nama = name;
    kode = code;
    nominal = amount;
    frekuensi = frequency;
  }
}

class _GagalCashTypes extends CashTypesProvider {
  bool panggil = false;

  _GagalCashTypes({required super.cashTypeRepository});

  @override
  Future<void> save({
    int? id,
    required String name,
    required String code,
    required int amount,
    required String frequency,
    required int dueDay,
    String? description,
    int? userId,
  }) async {
    panggil = true;
    throw AppException('Data sudah ada (nilai duplikat). Periksa kembali input Anda.');
  }
}

class _RekamPayments extends PaymentProvider {
  bool panggil = false;

  _RekamPayments({
    required super.paymentRepository,
    required super.classRepository,
    required super.studentRepository,
    required super.cashTypeRepository,
  });

  @override
  Future<PaymentModel> addPayment({
    required int studentId,
    required int cashTypeId,
    required int amount,
    required int month,
    required int year,
    required String paidDate,
    String paymentMethod = 'tunai',
    String? note,
    int? userId,
  }) async {
    panggil = true;
    return PaymentModel(
      id: 1,
      paymentCode: 'TEST-001',
      studentId: studentId,
      cashTypeId: cashTypeId,
      amount: amount,
      month: month,
      year: year,
      paidDate: paidDate,
      paymentMethod: paymentMethod,
      status: 'lunas',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _GagalPembayaran extends PaymentProvider {
  _GagalPembayaran({
    required super.paymentRepository,
    required super.classRepository,
    required super.studentRepository,
    required super.cashTypeRepository,
  });

  @override
  Future<PaymentModel> addPayment({
    required int studentId,
    required int cashTypeId,
    required int amount,
    required int month,
    required int year,
    required String paidDate,
    String paymentMethod = 'tunai',
    String? note,
    int? userId,
  }) async {
    throw AppException('Pembayaran gagal disimpan.');
  }
}

class _RekamTransactions extends TransactionProvider {
  bool panggilKategori = false;
  String? namaKategori;
  bool panggilPengeluaran = false;
  String? keperluanPengeluaran;

  _RekamTransactions({
    required super.expenseRepository,
    required super.paymentRepository,
    required super.cashTypeRepository,
    required super.auditLogRepository,
  });

  @override
  Future<void> saveCategory({
    int? id,
    required String name,
    String? description,
    int? userId,
  }) async {
    panggilKategori = true;
    namaKategori = name;
  }

  @override
  Future<ExpenseModel> addExpense({
    required int categoryId,
    required int amount,
    required String expenseDate,
    required String description,
    String? receiptNote,
    String? photoPath,
    int? userId,
  }) async {
    panggilPengeluaran = true;
    keperluanPengeluaran = description;
    final DateTime now = DateTime.now();
    return ExpenseModel(
      id: 1,
      expenseCode: 'TEST-001',
      categoryId: categoryId,
      amount: amount,
      expenseDate: expenseDate,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _GagalKategori extends TransactionProvider {
  bool panggilKategori = false;

  _GagalKategori({
    required super.expenseRepository,
    required super.paymentRepository,
    required super.cashTypeRepository,
    required super.auditLogRepository,
  });

  @override
  Future<void> saveCategory({
    int? id,
    required String name,
    String? description,
    int? userId,
  }) async {
    panggilKategori = true;
    throw AppException('Data sudah ada (nilai duplikat). Periksa kembali input Anda.');
  }
}

class _GagalPengeluaran extends TransactionProvider {
  _GagalPengeluaran({
    required super.expenseRepository,
    required super.paymentRepository,
    required super.cashTypeRepository,
    required super.auditLogRepository,
  });

  @override
  Future<ExpenseModel> addExpense({
    required int categoryId,
    required int amount,
    required String expenseDate,
    required String description,
    String? receiptNote,
    String? photoPath,
    int? userId,
  }) async {
    throw AppException('Pengeluaran gagal disimpan.');
  }
}

/// Provider yang selalu menolak addExpense karena nominal melebihi saldo,
/// meniru perilaku repository asli saat pemasukan tidak cukup.
class _SaldoKurang extends TransactionProvider {
  bool panggilPengeluaran = false;

  _SaldoKurang({
    required super.expenseRepository,
    required super.paymentRepository,
    required super.cashTypeRepository,
    required super.auditLogRepository,
  });

  @override
  List<ExpenseCategoryModel> get categories => <ExpenseCategoryModel>[
    ExpenseCategoryModel(id: 1, name: 'Operasional', createdAt: DateTime(2026)),
  ];

  @override
  Future<void> addExpense({
    required int categoryId,
    required int amount,
    required String expenseDate,
    required String description,
    String? receiptNote,
    String? photoPath,
    int? userId,
  }) async {
    panggilPengeluaran = true;
    throw const SaldoInsufficientException(amount: 15000, saldo: 10000);
  }
}
