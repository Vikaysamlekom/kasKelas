import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/app_error.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/expense_category_model.dart';
import 'package:kas_bintang_nusantara/models/student_model.dart';
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
import 'package:kas_bintang_nusantara/screens/pengeluaran/kategori_pengeluaran_screen.dart';
import 'package:kas_bintang_nusantara/screens/students/student_detail_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji tombol HAPUS / UBAH STATUS.
///
/// Fokus utama: aksi yang sebelumnya TIDAK punya penanganan error. Error
/// database membuat dialog tertutup tanpa pesan apa pun, sehingga tombol
/// terlihat "tidak merespons". Setiap test memakai provider yang melempar
/// error untuk membuktikan pesan itu benar-benar sampai ke pengguna.
void main() {
  const String dbNameTest = 'delete_flows_test';

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

  void smokeTest(String nama, Future<void> Function(WidgetTester) body) {
    testWidgets(nama, (WidgetTester tester) async {
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

List<SingleChildWidget> baseProviders({
    required TransactionProvider transactions,
    required StudentsProvider students,
    required PaymentProvider payments,
  }) {
    return <SingleChildWidget>[
      ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
      ChangeNotifierProvider<StudentsProvider>.value(value: students),
      ChangeNotifierProvider<PaymentProvider>.value(value: payments),
      ChangeNotifierProvider<SessionProvider>(
        create: (_) => SessionProvider(authRepository: AuthRepository()),
      ),
      ChangeNotifierProvider<ClassesProvider>(
        create: (_) => ClassesProvider(classRepository: ClassRepository()),
      ),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
    ];
  }

  // ============================================================
  // HAPUS KATEGORI PENGELUARAN
  // ============================================================

  group('Tombol Hapus Kategori', () {
    smokeTest('gagal hapus: pesan error sampai ke pengguna', (
      WidgetTester tester,
    ) async {
      final _GagalKategori p = _GagalKategori(
        expenseRepository: ExpenseRepository(),
        paymentRepository: PaymentRepository(),
        cashTypeRepository: CashTypeRepository(),
        auditLogRepository: AuditLogRepository(),
      );
p.kategori = ExpenseCategoryModel(
        id: 7,
        name: 'Operasional',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: baseProviders(
            transactions: p,
            students: StudentsProvider(
              studentRepository: StudentRepository(),
              classRepository: ClassRepository(),
            ),
            payments: PaymentProvider(
              paymentRepository: PaymentRepository(),
              classRepository: ClassRepository(),
              studentRepository: StudentRepository(),
              cashTypeRepository: CashTypeRepository(),
            ),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const KategoriPengeluaranScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await ketuk(tester, find.byTooltip('Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Dialog konfirmasi harus muncul, lalu dicoret "Ya, Hapus".
      expect(find.text('Hapus Kategori'), findsOneWidget);
      await ketuk(tester, find.text('Ya, Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(p.panggil, isTrue, reason: 'Provider hapus tidak dipanggil');
      expect(
        find.textContaining('Operasional'),
        findsWidgets,
        reason: 'Pesan hasil/gagal hapus tidak tampil ke pengguna',
      );
      expect(find.byType(SnackBar), findsWidgets);
    });

    smokeTest('batal di dialog: provider TIDAK dipanggil', (
      WidgetTester tester,
    ) async {
      final _GagalKategori p = _GagalKategori(
        expenseRepository: ExpenseRepository(),
        paymentRepository: PaymentRepository(),
        cashTypeRepository: CashTypeRepository(),
        auditLogRepository: AuditLogRepository(),
      );
p.kategori = ExpenseCategoryModel(
        id: 7,
        name: 'Operasional',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: baseProviders(
            transactions: p,
            students: StudentsProvider(
              studentRepository: StudentRepository(),
              classRepository: ClassRepository(),
            ),
            payments: PaymentProvider(
              paymentRepository: PaymentRepository(),
              classRepository: ClassRepository(),
              studentRepository: StudentRepository(),
              cashTypeRepository: CashTypeRepository(),
            ),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const KategoriPengeluaranScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await ketuk(tester, find.byTooltip('Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await ketuk(tester, find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(p.panggil, isFalse, reason: 'Batal tidak boleh menghapus data');
    });
  });

  // ============================================================
  // HAPUS / UBAH STATUS SISWA
  // ============================================================

  group('Tombol Siswa di Detail', () {
    smokeTest('gagal hapus siswa: pesan error sampai ke pengguna', (
      WidgetTester tester,
    ) async {
      final _GagalSiswa p = _GagalSiswa(
        studentRepository: StudentRepository(),
        classRepository: ClassRepository(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: baseProviders(
            transactions: TransactionProvider(
              expenseRepository: ExpenseRepository(),
              paymentRepository: PaymentRepository(),
              cashTypeRepository: CashTypeRepository(),
              auditLogRepository: AuditLogRepository(),
            ),
            students: p,
            payments: PaymentProvider(
              paymentRepository: PaymentRepository(),
              classRepository: ClassRepository(),
              studentRepository: StudentRepository(),
              cashTypeRepository: CashTypeRepository(),
            ),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StudentDetailScreen(studentId: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await ketuk(tester, find.text('Hapus Siswa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await ketuk(tester, find.text('Ya, Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(p.panggilHapus, isTrue);
      expect(
        find.byType(SnackBar),
        findsWidgets,
        reason: 'Gagal hapus siswa tidak memberi feedback ke pengguna',
      );
      expect(find.textContaining('Siswa tidak bisa dihapus'), findsWidgets);
    });

    smokeTest('gagal ubah status: pesan error sampai ke pengguna', (
      WidgetTester tester,
    ) async {
      final _GagalSiswa p = _GagalSiswa(
        studentRepository: StudentRepository(),
        classRepository: ClassRepository(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: baseProviders(
            transactions: TransactionProvider(
              expenseRepository: ExpenseRepository(),
              paymentRepository: PaymentRepository(),
              cashTypeRepository: CashTypeRepository(),
              auditLogRepository: AuditLogRepository(),
            ),
            students: p,
            payments: PaymentProvider(
              paymentRepository: PaymentRepository(),
              classRepository: ClassRepository(),
              studentRepository: StudentRepository(),
              cashTypeRepository: CashTypeRepository(),
            ),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StudentDetailScreen(studentId: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await ketuk(tester, find.text('Ubah Status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ubah Status Siswa'), findsOneWidget);

      await ketuk(tester, find.text('Lulus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(p.panggilStatus, isTrue);
      expect(
        find.textContaining('Status gagal diubah'),
        findsWidgets,
        reason: 'Gagal ubah status tidak memberi feedback ke pengguna',
      );
    });
  });
}

// ============================================================================
// PROVIDER UJI COBA
// ============================================================================

class _GagalKategori extends TransactionProvider {
  bool panggil = false;
  ExpenseCategoryModel? kategori;

  _GagalKategori({
    required super.expenseRepository,
    required super.paymentRepository,
    required super.cashTypeRepository,
    required super.auditLogRepository,
  });

@override
  List<ExpenseCategoryModel> get categories {
    final ExpenseCategoryModel? c = kategori;
    return c == null ? <ExpenseCategoryModel>[] : <ExpenseCategoryModel>[c];
  }

  @override
  Future<DeleteResult> deleteCategory(int id, {int? userId}) async {
    panggil = true;
    throw AppException('Kategori masih dipakai pengeluaran.');
  }
}

class _GagalSiswa extends StudentsProvider {
  bool panggilHapus = false;
  bool panggilStatus = false;

  _GagalSiswa({
    required super.studentRepository,
    required super.classRepository,
  });

@override
  Future<int> paymentCount(int id) async => 0;

  @override
  Future<StudentModel?> studentById(int id) async => StudentModel(
        id: id,
        nis: '0001',
        name: 'Ahmad Fauzi',
        gender: 'L',
        classId: 1,
        status: 'aktif',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<bool> deleteStudent(int id, {int? userId}) async {
    panggilHapus = true;
    throw AppException('Siswa tidak bisa dihapus.');
  }

  @override
  Future<StudentModel?> changeStatus(int id, String status, {int? userId}) async {
    panggilStatus = true;
    throw AppException('Status gagal diubah.');
  }
}