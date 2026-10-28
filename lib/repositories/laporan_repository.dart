import 'dart:collection';

import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';
import '../models/cash_type_model.dart';
import '../models/laporan_model.dart';
import '../models/payment_model.dart';
import 'pembayaran_repo.dart';

/// Repository perhitungan laporan keuangan:
/// pemasukan, pengeluaran, saldo, dan pembayaran per siswa.
class LaporanRepository {
  final DBHelper _db = DBHelper.instance;
  final PaymentRepository _paymentRepository = PaymentRepository();

  // ------------------------------------------------------------
  // PEMASUKAN
  // ------------------------------------------------------------

  Future<List<LaporanBaris>> pemasukan({
    required PeriodeLaporan periode,
    required KelompokLaporan kelompok,
    int? classId,
    int? majorId,
    int? cashTypeId,
  }) async {
    final List<String> where = <String>[
      "p.status != '${PaymentStatus.batal}'",
      'substr(p.paid_date, 1, 10) >= ?',
      'substr(p.paid_date, 1, 10) <= ?',
    ];
    final List<Object?> args = <Object?>[periode.startKey, periode.endKey];
    if (classId != null) {
      where.add('s.class_id = ?');
      args.add(classId);
    }
    if (majorId != null) {
      where.add('COALESCE(s.major_id, c.major_id) = ?');
      args.add(majorId);
    }
    if (cashTypeId != null) {
      where.add('p.cash_type_id = ?');
      args.add(cashTypeId);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery('''
      SELECT p.paid_date, p.amount, c.name AS class_name,
             m.name AS major_name, ct.name AS cash_type_name
      FROM ${DBHelper.tblPayments} p
      JOIN ${DBHelper.tblStudents} s ON s.id = p.student_id
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblMajors} m
        ON m.id = COALESCE(s.major_id, c.major_id)
      LEFT JOIN ${DBHelper.tblCashTypes} ct ON ct.id = p.cash_type_id
      WHERE ${where.join(' AND ')}
      ORDER BY p.paid_date ASC
      ''', args);
    return _kelompokkan(rows, kelompok, 'paid_date');
  }

  // ------------------------------------------------------------
  // PENGELUARAN
  // ------------------------------------------------------------

  Future<List<LaporanBaris>> pengeluaran({
    required PeriodeLaporan periode,
    required KelompokLaporan kelompok,
    int? categoryId,
  }) async {
    final List<String> where = <String>[
      "status != '${PaymentStatus.batal}'",
      'substr(expense_date, 1, 10) >= ?',
      'substr(expense_date, 1, 10) <= ?',
    ];
    final List<Object?> args = <Object?>[periode.startKey, periode.endKey];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery('''
      SELECT expense_date, amount, e.category_id,
             c.name AS category_name
      FROM ${DBHelper.tblExpenses} e
      LEFT JOIN ${DBHelper.tblExpenseCategories} c ON c.id = e.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY e.expense_date ASC
      ''', args);
    return _kelompokkanExpense(rows, kelompok);
  }

  // ------------------------------------------------------------
  // SALDO
  // ------------------------------------------------------------

  Future<LaporanSaldo> saldo({required PeriodeLaporan periode}) async {
    final int saldoAwal = await _saldoSebelum(periode.startKey);
    final int masuk = await _sumPemasukan(periode);
    final int keluar = await _sumPengeluaran(periode);
    return LaporanSaldo(
      saldoAwal: saldoAwal,
      pemasukan: masuk,
      pengeluaran: keluar,
      saldoAkhir: saldoAwal + masuk - keluar,
    );
  }

  Future<int> _saldoSebelum(String startKey) async {
    final List<Map<String, Object?>> masuk = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblPayments} '
      "WHERE status != '${PaymentStatus.batal}' "
      'AND substr(paid_date, 1, 10) < ?',
      <Object?>[startKey],
    );
    final List<Map<String, Object?>> keluar = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblExpenses} '
      "WHERE status != '${PaymentStatus.batal}' "
      'AND substr(expense_date, 1, 10) < ?',
      <Object?>[startKey],
    );
    return (Sqflite.firstIntValue(masuk) ?? 0) - (Sqflite.firstIntValue(keluar) ?? 0);
  }

  Future<int> _sumPemasukan(PeriodeLaporan periode) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblPayments} '
      "WHERE status != '${PaymentStatus.batal}' "
      'AND substr(paid_date, 1, 10) >= ? AND substr(paid_date, 1, 10) <= ?',
      <Object?>[periode.startKey, periode.endKey],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> _sumPengeluaran(PeriodeLaporan periode) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblExpenses} '
      "WHERE status != '${PaymentStatus.batal}' "
      'AND substr(expense_date, 1, 10) >= ? '
      'AND substr(expense_date, 1, 10) <= ?',
      <Object?>[periode.startKey, periode.endKey],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ------------------------------------------------------------
  // PEMBAYARAN SISWA (TAGIHAN / BAYAR / TUNGGAKAN)
  // ------------------------------------------------------------

  Future<List<LaporanPembayaranSiswa>> pembayaranSiswa({
    required PeriodeLaporan periode,
    int? classId,
    int? majorId,
    String? statusFilter,
  }) async {
    final List<String> where = <String>["s.status = 'aktif'", 's.is_active = 1'];
    final List<Object?> args = <Object?>[];
    if (classId != null) {
      where.add('s.class_id = ?');
      args.add(classId);
    }
    if (majorId != null) {
      where.add('COALESCE(s.major_id, c.major_id) = ?');
      args.add(majorId);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT s.nis, s.name, c.name AS class_name, m.name AS major_name,
             COALESCE(SUM(
               CASE WHEN p.status != '${PaymentStatus.batal}'
                     AND substr(p.paid_date, 1, 10) >= ?
                     AND substr(p.paid_date, 1, 10) <= ?
                 THEN p.amount ELSE 0 END
             ), 0) AS bayar
      FROM ${DBHelper.tblStudents} s
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblMajors} m
        ON m.id = COALESCE(s.major_id, c.major_id)
      LEFT JOIN ${DBHelper.tblPayments} p ON p.student_id = s.id
      WHERE ${where.join(' AND ')}
      GROUP BY s.id
      ORDER BY c.level ASC, c.name ASC, s.name ASC
      ''',
      <Object?>[periode.startKey, periode.endKey, ...args],
    );

    final List<Map<String, Object?>> cashTypeRows = await _db.rawQuery(
      'SELECT * FROM ${DBHelper.tblCashTypes} WHERE is_active = 1',
    );
    final List<CashTypeModel> cashTypes = cashTypeRows
        .map(CashTypeModel.fromMap)
        .toList();
    final int owedPerSiswa = cashTypes.fold<int>(
      0,
      (int total, CashTypeModel cashType) =>
          total +
          _paymentRepository.owedForCashTypeInRange(
            cashType,
            start: periode.start,
            end: periode.end,
          ),
    );

    final List<LaporanPembayaranSiswa> result = <LaporanPembayaranSiswa>[];
    for (final Map<String, Object?> r in rows) {
      final int bayar = (r['bayar'] as int?) ?? 0;
      final int sisa = bayar >= owedPerSiswa ? 0 : owedPerSiswa - bayar;
      String status;
      if (owedPerSiswa <= 0 || bayar >= owedPerSiswa) {
        status = PaymentStatus.lunas;
      } else if (bayar > 0) {
        status = PaymentStatus.sebagian;
      } else {
        status = PaymentStatus.belum;
      }
      if (statusFilter != null && statusFilter.isNotEmpty && status != statusFilter) {
        continue;
      }
      result.add(
        LaporanPembayaranSiswa(
          nis: r['nis'] as String,
          name: r['name'] as String,
          className: r['class_name'] as String?,
          majorName: r['major_name'] as String?,
          tagihan: owedPerSiswa,
          bayar: bayar,
          tunggakan: sisa,
          status: status,
        ),
      );
    }
    return result;
  }

  // ------------------------------------------------------------
  // GROUPING
  // ------------------------------------------------------------

  List<LaporanBaris> _kelompokkan(
    List<Map<String, Object?>> rows,
    KelompokLaporan kelompok,
    String dateColumn,
  ) {
    final LinkedHashMap<String, (int, int)> map = LinkedHashMap<String, (int, int)>();
    for (final Map<String, Object?> r in rows) {
      final String key = _keyPemasukan(r, kelompok, dateColumn);
      final (int, int) cur = map[key] ?? (0, 0);
      map[key] = (cur.$1 + 1, cur.$2 + ((r['amount'] as int?) ?? 0));
    }
    return _toBaris(map, kelompok);
  }

  List<LaporanBaris> _kelompokkanExpense(
    List<Map<String, Object?>> rows,
    KelompokLaporan kelompok,
  ) {
    final LinkedHashMap<String, (int, int)> map = LinkedHashMap<String, (int, int)>();
    for (final Map<String, Object?> r in rows) {
      final String key;
      switch (kelompok) {
        case KelompokLaporan.perTanggal:
          key = (r['expense_date'] as String).substring(0, 10);
        case KelompokLaporan.perBulan:
          key = (r['expense_date'] as String).substring(0, 7);
        case KelompokLaporan.perKategori:
          key = (r['category_name'] as String?) ?? '-';
        default:
          key = (r['category_name'] as String?) ?? '-';
      }
      final (int, int) cur = map[key] ?? (0, 0);
      map[key] = (cur.$1 + 1, cur.$2 + ((r['amount'] as int?) ?? 0));
    }
    return _toBaris(map, kelompok);
  }

  String _keyPemasukan(Map<String, Object?> r, KelompokLaporan kelompok, String dateColumn) {
    switch (kelompok) {
      case KelompokLaporan.perTanggal:
        return (r[dateColumn] as String).substring(0, 10);
      case KelompokLaporan.perBulan:
        return (r[dateColumn] as String).substring(0, 7);
      case KelompokLaporan.perKelas:
        return (r['class_name'] as String?) ?? '-';
      case KelompokLaporan.perJurusan:
        return (r['major_name'] as String?) ?? '-';
      case KelompokLaporan.perJenisKas:
        return (r['cash_type_name'] as String?) ?? '-';
      default:
        return (r[dateColumn] as String).substring(0, 10);
    }
  }

  List<LaporanBaris> _toBaris(LinkedHashMap<String, (int, int)> map, KelompokLaporan kelompok) {
    final bool byTanggalBulan =
        kelompok == KelompokLaporan.perTanggal || kelompok == KelompokLaporan.perBulan;
    final List<String> keys = map.keys.toList();
    if (byTanggalBulan) {
      keys.sort();
    } else {
      keys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return keys.map((String k) {
      final (int, int) v = map[k]!;
      return LaporanBaris(label: _labelKey(k), jumlah: v.$1, nominal: v.$2);
    }).toList();
  }

  String _labelKey(String key) {
    if (key.length == 10) {
      // yyyy-MM-dd
      final DateTime d = DateTime.tryParse(key) ?? DateTime.now();
      return '${d.day.toString().padLeft(2, '0')} '
          '${_bulanShort(d.month)} ${d.year}';
    }
    if (key.length == 7) {
      final DateTime d = DateTime.tryParse('$key-01') ?? DateTime.now();
      return '${_bulanFull(d.month)} ${d.year}';
    }
    return key;
  }

  String _bulanShort(int m) {
    const List<String> nama = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return nama[m - 1];
  }

  String _bulanFull(int m) {
    const List<String> nama = <String>[
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return nama[m - 1];
  }
}
