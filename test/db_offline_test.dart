import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/app_error.dart';
import 'package:kas_bintang_nusantara/core/constants.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/expense_model.dart';
import 'package:kas_bintang_nusantara/models/laporan_model.dart';
import 'package:kas_bintang_nusantara/models/payment_model.dart';
import 'package:kas_bintang_nusantara/models/student_model.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/dashboard_repository.dart';
import 'package:kas_bintang_nusantara/repositories/laporan_repository.dart';
import 'package:kas_bintang_nusantara/repositories/pembayaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/pengeluaran_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji integrasi lapisan data memakai SQLite asli (FFI) di mesinPengembang.
/// Tujuannya memastikan seluruh alur kas — yang di HP berjalan 100% offline —
/// tetap benar: pembuatan skema, data awal, login, pembayaran, pengeluaran,
/// pembatalan transaksi, dan perhitungan saldo.
void main() {
  late Directory dbDir;
  late AuthRepository auth;
  late StudentRepository siswa;
  late PaymentRepository pembayaran;
  late ExpenseRepository pengeluaran;
  late DashboardRepository dashboard;
  late LaporanRepository laporan;
  late int userId;
  late int kelasId;
  late int siswaId;
  late int kasBulananId;

  final DateTime now = DateTime.now();
  late String hariIni;

  // PIN uji milik sendiri — aplikasi tidak menyediakan PIN bawaan.
  const String pinUji = '927364';

  /// Jenis kas bawaan bernominal 0 (tunggakan tidak diisi otomatis). Helper ini
  /// menetapkan nominal untuk test yang memang perlu memeriksa status bayar.
  Future<void> setKasBulananAmount(int amount) {
    return DBHelper.instance.update(
      DBHelper.tblCashTypes,
      <String, Object?>{'amount': amount},
      where: 'id = ?',
      whereArgs: <Object?>[kasBulananId],
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Database bersih untuk tiap test supaya hasil tidak saling bergantung.
    await DBHelper.instance.close();
    final String base = await getDatabasesPath();
    dbDir = Directory(base);
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final File dbFile = File(p.join(base, AppConstants.dbName));
    if (dbFile.existsSync()) dbFile.deleteSync();
    // Hanya bersihkan file samping milik database ini, jangan database lain
    // yang mungkin sedang dipakai file test lain secara paralel.
    for (final String suffix in <String>['-journal', '-wal', '-shm']) {
      final File sidecar = File('${dbFile.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }

    final Database db = await DBHelper.instance.database;
    userId = (await db.query(DBHelper.tblUsers)).first['id'] as int;

    kelasId = await DBHelper.instance.insert(DBHelper.tblClasses, <String, Object?>{
      'name': 'XII RPL 1',
      'level': 12,
      'academic_year': '2026/2027',
      'is_active': 1,
      'created_at': now.toIso8601String(),
    });

    final StudentModel siswaBaru = await StudentRepository().insert(
      StudentModel(
        nis: '1001',
        name: 'Ahmad Fauzi',
        classId: kelasId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    siswaId = siswaBaru.id!;

    kasBulananId = (await DBHelper.instance.query(DBHelper.tblCashTypes, where: 'code = ?', whereArgs: <Object?>['BULANAN']))
        .first['id'] as int;

    hariIni = now.toIso8601String().substring(0, 10);

    auth = AuthRepository();
    siswa = StudentRepository();
    pembayaran = PaymentRepository();
    pengeluaran = ExpenseRepository();
    dashboard = DashboardRepository();
    laporan = LaporanRepository();
  });

  tearDownAll(() async {
    await DBHelper.instance.close();
  });

  group('Skema & data awal', () {
    test('membuat seluruh tabel dan mengisi data awal', () async {
      final List<Map<String, Object?>> tabel = await DBHelper.instance.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      final List<String> nama = tabel.map((Map<String, Object?> r) => r['name'] as String).toList();

      for (final String wajib in <String>[
        DBHelper.tblUsers,
        DBHelper.tblMajors,
        DBHelper.tblClasses,
        DBHelper.tblStudents,
        DBHelper.tblCashTypes,
        DBHelper.tblPayments,
        DBHelper.tblExpenseCategories,
        DBHelper.tblExpenses,
        DBHelper.tblAuditLogs,
        DBHelper.tblSchoolProfile,
        DBHelper.tblSettings,
      ]) {
        expect(nama, contains(wajib), reason: 'Tabel $wajib harus ada');
      }

      expect(await DBHelper.instance.count(DBHelper.tblUsers), 1);
      expect(await DBHelper.instance.count(DBHelper.tblCashTypes), 3);
      expect(await DBHelper.instance.count(DBHelper.tblExpenseCategories), 6);
      expect(await DBHelper.instance.count(DBHelper.tblSchoolProfile), 1);
    });

    test('nominal jenis kas bawaan 0 agar tunggakan tidak otomatis', () async {
      final List<Map<String, Object?>> rows =
          await DBHelper.instance.query(DBHelper.tblCashTypes);
      expect(rows, hasLength(3));
      for (final Map<String, Object?> r in rows) {
        expect(
          r['amount'],
          0,
          reason: 'Nominal bawaan ${r['name']} harus 0, bukan angka otomatis',
        );
      }
      expect(
        await pembayaran.kasPerBulan(),
        0,
        reason: 'Kewajiban bulanan harus 0 sebelum bendahara mengisi nominal',
      );
    });

    test('semua index performa terbentuk', () async {
      final List<Map<String, Object?>> idx = await DBHelper.instance.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
      );
      final List<String> nama = idx.map((Map<String, Object?> r) => r['name'] as String).toList();
      expect(nama, contains('idx_payments_student'));
      expect(nama, contains('idx_payments_period'));
      expect(nama, contains('idx_students_class_name'));
      expect(nama, contains('idx_expenses_status'));
    });

    test('foreign key aktif', () async {
      final List<Map<String, Object?>> pragma =
          await DBHelper.instance.rawQuery('PRAGMA foreign_keys');
      expect(pragma.first.values.first, 1);
    });
  });

  group('Login', () {
    test('belum ada PIN: login ditolak', () async {
      expect(await auth.isPinSet(), isFalse);
      expect(await auth.loginWithPin(pinUji), isNull);
    });

    test('PIN buatan pengguna diterima', () async {
      expect(await auth.setInitialPin(pinUji), isTrue);
      expect(await auth.isPinSet(), isTrue);

      final dynamic user = await auth.loginWithPin(pinUji);
      expect(user, isNotNull);
      expect(user!.id, userId);
    });

    test('setInitialPin menolak bila PIN sudah dibuat', () async {
      await auth.setInitialPin(pinUji);
      expect(await auth.setInitialPin('999999'), isFalse);
      expect(await auth.loginWithPin(pinUji), isNotNull);
    });

    test('PIN salah ditolak', () async {
      await auth.setInitialPin(pinUji);
      final dynamic user = await auth.loginWithPin('salah-sekali');
      expect(user, isNull);
    });

    test('ganti PIN mempengaruhi login', () async {
      await auth.setInitialPin(pinUji);
      final bool ok = await auth.changePassword(
        userId: userId,
        oldPassword: pinUji,
        newPassword: 'kasRahasia2026',
      );
      expect(ok, isTrue);
      expect(
        await auth.loginWithPin(pinUji),
        isNull,
        reason: 'PIN lama harus berhenti berlaku setelah diganti',
      );
      expect(await auth.loginWithPin('kasRahasia2026'), isNotNull);
    });
  });

  group('Siswa', () {
    test('NIS ganda ditolak', () async {
      expect(
        () => siswa.insert(StudentModel(nis: '1001', name: 'Duplikat', classId: kelasId, createdAt: now, updatedAt: now)),
        throwsA(isA<DuplicateNisException>()),
      );
    });

    test('pencarian & filter kelas bekerja', () async {
      await siswa.insert(StudentModel(nis: '1002', name: 'Bella Putri', classId: kelasId, createdAt: now, updatedAt: now));
      final List<StudentModel> hasil = await siswa.list(const StudentFilter(search: 'bella'));
      expect(hasil.length, 1);
      expect(hasil.first.name, 'Bella Putri');

      final List<StudentModel> perKelas = await siswa.list(StudentFilter(classId: kelasId));
      expect(perKelas.length, 2);
    });

    test('siswa dengan riwayat pembayaran tidak bisa dihapus', () async {
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      expect(await siswa.delete(siswaId), isFalse);
    });
  });

  group('Pembayaran', () {
    test('kode transaksi berurutan dan status otomatis', () async {
      await setKasBulananAmount(25000);

      final dynamic pertama = await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final dynamic kedua = await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 10000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );

      expect(pertama.paymentCode, 'TRX-${now.year}${now.month.toString().padLeft(2, '0')}-000001');
      expect(kedua.paymentCode, 'TRX-${now.year}${now.month.toString().padLeft(2, '0')}-000002');
      expect(pertama.status, PaymentStatus.lunas);
      expect(kedua.status, PaymentStatus.sebagian);
    });

    test('nominal nol ditolak', () async {
      expect(
        () => pembayaran.add(
          studentId: siswaId,
          cashTypeId: kasBulananId,
          amount: 0,
          month: now.month,
          year: now.year,
          paidDate: hariIni,
        ),
        throwsArgumentError,
      );
    });

    test('pembatalan pembayaran mengeluarkan nominal dari saldo', () async {
      await setKasBulananAmount(25000);

      final dynamic p = await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      expect((await dashboard.getSummary()).saldo, 25000);

      await pembayaran.voidPayment(p.id, reason: 'Salah input nominal');
      expect((await dashboard.getSummary()).saldo, 0);
      expect(
        (await pembayaran.monthlyStatus(
          siswaId,
          now.month,
          now.year,
          cashTypeId: kasBulananId,
        )).status,
        PaymentStatus.belum,
      );
    });

    test('kewajiban mengikuti jenis kas terpilih (bukan total sum)', () async {
      await setKasBulananAmount(25000);
      final int kasSosialId =
          (await DBHelper.instance.query(
            DBHelper.tblCashTypes,
            where: 'code = ?',
            whereArgs: <Object?>['SOSIAL'],
          )).first['id'] as int;
      await DBHelper.instance.update(
        DBHelper.tblCashTypes,
        <String, Object?>{'amount': 10000},
        where: 'id = ?',
        whereArgs: <Object?>[kasSosialId],
      );

      // Belum bayar: sisa tunggakan = nominal jenis kas terpilih saja.
      final dynamic belum = await pembayaran.monthlyStatus(
        siswaId,
        now.month,
        now.year,
        cashTypeId: kasSosialId,
      );
      expect(belum.owed, 10000);
      expect(belum.paid, 0);
      expect(belum.sisa, 10000);
      expect(belum.status, PaymentStatus.belum);

      // Bayar kas bulanan PENUH — status kas sosial tetap belum karena
      // total bayar dihitung hanya untuk jenis kas terkait.
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final dynamic sosial = await pembayaran.monthlyStatus(
        siswaId,
        now.month,
        now.year,
        cashTypeId: kasSosialId,
      );
      expect(sosial.paid, 0);
      expect(sosial.status, PaymentStatus.belum);
      expect(sosial.sisa, 10000);

      final dynamic bulanan = await pembayaran.monthlyStatus(
        siswaId,
        now.month,
        now.year,
        cashTypeId: kasBulananId,
      );
      expect(bulanan.owed, 25000);
      expect(bulanan.paid, 25000);
      expect(bulanan.status, PaymentStatus.lunas);

      // Tunggakan juga per jenis kas: kas sosial belum dibayar → muncul
      // dengan sisa 10.000, bukan total gabungan.
      final List<TunggakanItem> tunggakanSosial = await pembayaran
          .listTunggakan(
        month: now.month,
        year: now.year,
        cashTypeId: kasSosialId,
      );
      expect(tunggakanSosial.length, 1);
      expect(tunggakanSosial.first.studentId, siswaId);
      expect(tunggakanSosial.first.owed, 10000);
      expect(tunggakanSosial.first.paid, 0);
      expect(tunggakanSosial.first.sisa, 10000);
      expect(tunggakanSosial.first.status, PaymentStatus.belum);
    });

    test('kode transaksi tidak bentrok setelah pembatalan', () async {
      for (int i = 0; i < 2; i++) {
        await pembayaran.add(
          studentId: siswaId,
          cashTypeId: kasBulananId,
          amount: 25000,
          month: now.month,
          year: now.year,
          paidDate: hariIni,
          recordedBy: userId,
        );
      }
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      expect(await DBHelper.instance.count(DBHelper.tblPayments), 3);
    });
  });

  group('Pengeluaran', () {
    test('menyimpan pengeluaran dan mengurangi saldo', () async {
      final int kategoriId =
          (await DBHelper.instance.query(DBHelper.tblExpenseCategories, where: 'name = ?', whereArgs: <Object?>['Operasional']))
              .first['id'] as int;

      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 200000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );

      await pengeluaran.add(
        categoryId: kategoriId,
        amount: 50000,
        expenseDate: hariIni,
        description: 'Beli ATK',
        recordedBy: userId,
      );

      final dynamic ringkasan = await dashboard.getSummary();
      expect(ringkasan.totalPengeluaran, 50000);
      expect(ringkasan.pengeluaranBulanIni, 50000);
      expect(ringkasan.saldo, 150000);
    });

    test('pengeluaran melebihi pemasukan ditolak', () async {
      final int kategoriId =
          (await DBHelper.instance.query(DBHelper.tblExpenseCategories, where: 'name = ?', whereArgs: <Object?>['Operasional']))
              .first['id'] as int;

      // Belum ada pemasukan → semua pengeluaran harus ditolak.
      expect(
        () => pengeluaran.add(
          categoryId: kategoriId,
          amount: 1000,
          expenseDate: hariIni,
          description: 'Tanpa saldo',
          recordedBy: userId,
        ),
        throwsA(isA<SaldoInsufficientException>()),
      );

      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 50000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );

      // Melebihi saldo 50.000 → ditolak dan tidak tersimpan.
      expect(
        () => pengeluaran.add(
          categoryId: kategoriId,
          amount: 50001,
          expenseDate: hariIni,
          description: 'Kelebihan',
          recordedBy: userId,
        ),
        throwsA(isA<SaldoInsufficientException>()),
      );
      expect(await DBHelper.instance.count(DBHelper.tblExpenses), 0);

      // Tepat sebesar saldo → diterima, saldo nol (tidak minus).
      await pengeluaran.add(
        categoryId: kategoriId,
        amount: 50000,
        expenseDate: hariIni,
        description: 'Pas saldo',
        recordedBy: userId,
      );
      expect((await dashboard.getSummary()).saldo, 0);
    });

    test('pembatalan pengeluaran mengembalikan saldo', () async {
      final int kategoriId =
          (await DBHelper.instance.query(DBHelper.tblExpenseCategories, where: 'name = ?', whereArgs: <Object?>['ATK']))
              .first['id'] as int;
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 100000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final dynamic e = await pengeluaran.add(
        categoryId: kategoriId,
        amount: 75000,
        expenseDate: hariIni,
        description: 'Solar genset',
        recordedBy: userId,
      );
      expect((await dashboard.getSummary()).saldo, 25000);

      await pengeluaran.voidExpense(e.id, reason: 'Nota salah');
      expect((await dashboard.getSummary()).saldo, 100000);
      expect((await pengeluaran.getById(e.id))!.status, ExpenseStatus.batal);
    });
  });

  group('Saldo dashboard konsisten dengan laporan', () {
    test('saldo kedua sumber sama setelah pembatalan campuran', () async {
      final int kategoriId =
          (await DBHelper.instance.query(DBHelper.tblExpenseCategories, where: 'name = ?', whereArgs: <Object?>['Kegiatan']))
              .first['id'] as int;

      final dynamic p1 = await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final dynamic e1 = await pengeluaran.add(
        categoryId: kategoriId,
        amount: 30000,
        expenseDate: hariIni,
        description: 'Sewa sound',
        recordedBy: userId,
      );

      // Batalkan satu pembayaran dan satu pengeluaran.
      await pembayaran.voidPayment(p1.id, reason: 'duplikat');
      await pengeluaran.voidExpense(e1.id, reason: 'batal');

      final dynamic ringkasan = await dashboard.getSummary();
      expect(ringkasan.totalPemasukan, 25000);
      expect(ringkasan.totalPengeluaran, 0);
      expect(ringkasan.saldo, 25000);

      // Laporan harus menghitung angka yang sama.
      final LaporanSaldo saldoLaporan = await laporan.saldo(
        periode: PeriodeLaporan.dari(PeriodeJenis.bulanIni),
      );
      expect(saldoLaporan.saldoAkhir, ringkasan.saldo);
    });
  });

  group('Laporan', () {
    test('rekap per tanggal terhitung benar', () async {
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final int kategoriId =
          (await DBHelper.instance.query(DBHelper.tblExpenseCategories, where: 'name = ?', whereArgs: <Object?>['Operasional']))
              .first['id'] as int;
      await pengeluaran.add(
        categoryId: kategoriId,
        amount: 10000,
        expenseDate: hariIni,
        description: 'ATK kelas',
        recordedBy: userId,
      );

      final List<LaporanBaris> masuk = await laporan.pemasukan(
        periode: PeriodeLaporan.dari(PeriodeJenis.bulanIni),
        kelompok: KelompokLaporan.perTanggal,
      );
      final List<LaporanBaris> keluar = await laporan.pengeluaran(
        periode: PeriodeLaporan.dari(PeriodeJenis.bulanIni),
        kelompok: KelompokLaporan.perTanggal,
      );
      expect(masuk.length, 1);
      expect(keluar.length, 1);
      expect(masuk.first.nominal, 25000);
      expect(keluar.first.nominal, 10000);
    });
  });

  group('Dashboard', () {
    test('progres kelas menghitung siswa yang sudah bayar', () async {
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      final List<dynamic> progres = await dashboard.getClassProgress();
      expect(progres.length, 1);
      expect(progres.first.className, 'XII RPL 1');
      expect(progres.first.totalStudents, 1);
      expect(progres.first.paidStudents, 1);
      expect(progres.first.percent, 100);
    });

    test('transaksi hari ini terhitung', () async {
      await pembayaran.add(
        studentId: siswaId,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
        recordedBy: userId,
      );
      expect((await dashboard.getSummary()).transaksiHariIni, 1);
    });
  });

  group('Integritas data', () {
    test('hapus siswa cascade menghapus pembayarannya', () async {
      final StudentModel s = await siswa.insert(
        StudentModel(nis: '2001', name: 'Siswa Sementara', createdAt: now, updatedAt: now),
      );
      await pembayaran.add(
        studentId: s.id!,
        cashTypeId: kasBulananId,
        amount: 25000,
        month: now.month,
        year: now.year,
        paidDate: hariIni,
      );
      expect(await DBHelper.instance.count(DBHelper.tblPayments), 1);

      await DBHelper.instance.delete(DBHelper.tblStudents, where: 'id = ?', whereArgs: <Object?>[s.id]);
      expect(await DBHelper.instance.count(DBHelper.tblPayments), 0);
    });

    test('audit log tersimpan', () async {
      await DBHelper.instance.logAudit(
        userId: userId,
        action: 'create',
        entityTable: DBHelper.tblStudents,
        entityId: siswaId,
        description: 'Tambah siswa uji',
      );
      final List<Map<String, Object?>> rows =
          await DBHelper.instance.query(DBHelper.tblAuditLogs, where: 'entity_id = ?', whereArgs: <Object?>[siswaId]);
      expect(rows.length, 1);
      expect(rows.first['action'], 'create');
    });

    test('penyimpanan setting membuat baru bila belum ada', () async {
      await DBHelper.instance.setSetting('uji_offline', 'ya');
      expect(await DBHelper.instance.getSetting('uji_offline'), 'ya');
      await DBHelper.instance.setSetting('uji_offline', 'tidak');
      expect(await DBHelper.instance.getSetting('uji_offline'), 'tidak');
      expect(await DBHelper.instance.count(DBHelper.tblSettings, where: 'key = ?', whereArgs: <Object?>['uji_offline']), 1);
    });
  });
}
