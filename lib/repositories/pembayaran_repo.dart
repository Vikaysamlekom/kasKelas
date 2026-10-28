import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';
import '../models/cash_type_model.dart';
import '../models/payment_model.dart';
import '../models/payment_period.dart';

/// Status pembayaran satu siswa pada satu periode (bulan + tahun) untuk
/// SATU jenis kas yang sedang dipilih. Kewajiban (owed) = nominal dari
/// jenis kas tersebut, bukan jumlah seluruh jenis kas.
class PeriodStatus {
  final int owed;
  final int paid;
  final int sisa;
  final String status; // lunas / sebagian / belum

  const PeriodStatus({
    required this.owed,
    required this.paid,
    required this.sisa,
    required this.status,
  });
}

/// Item tunggakan: satu siswa + sisa kewajiban pada periode terpilih.
class TunggakanItem {
  final int studentId;
  final String nis;
  final String name;
  final String? className;
  final String? majorName;
  final int owed;
  final int paid;
  final int sisa;
  final String status; // lunas / sebagian / belum

  const TunggakanItem({
    required this.studentId,
    required this.nis,
    required this.name,
    this.className,
    this.majorName,
    required this.owed,
    required this.paid,
    required this.sisa,
    required this.status,
  });
}

/// Repository data pembayaran (payments): pencatatan, daftar, status
/// otomatis, tunggakan, dan kode transaksi otomatis.
class PaymentRepository {
  final DBHelper _db = DBHelper.instance;

  /// Total kas per bulan (jumlah nominal jenis kas berfrekuensi `bulanan`
  /// yang masih aktif). CATATAN: kini hanya dipakai laporan pembayaran
  /// siswa. Status kewajiban per siswa di form & tunggakan memakai
  /// nominal jenis kas terpilih (lihat [monthlyStatus] & [listTunggakan]).
  Future<int> kasPerBulan() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblCashTypes} "
      "WHERE is_active = 1 AND frequency = 'bulanan'",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Kode transaksi otomatis berikutnya → TRX-{tahun}{bulan2}-{urutan6}.
  Future<String> nextPaymentCode(int year, int month) async {
    final String mm = month.toString().padLeft(2, '0');
    final String prefix = 'TRX-$year$mm';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT payment_code FROM ${DBHelper.tblPayments} '
      'WHERE payment_code LIKE ? ORDER BY payment_code DESC LIMIT 1',
      <Object?>['$prefix-%'],
    );
    if (rows.isEmpty) return '$prefix-000001';
    final String last = rows.first['payment_code'] as String;
    final int seq = int.tryParse(last.split('-').last) ?? 0;
    return '$prefix-${(seq + 1).toString().padLeft(6, '0')}';
  }

  /// Simpan pembayaran baru (no transaksi otomatis, status auto).
  Future<PaymentModel> add({
    required int studentId,
    required int cashTypeId,
    required int amount,
    required int month,
    required int year,
    required String paidDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    String paymentMethod = 'tunai',
    String? note,
    int? recordedBy,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Nominal pembayaran harus lebih dari 0.');
    }
    final CashTypeModel? cashType = await getCashType(cashTypeId);
    if (cashType == null) {
      throw StateError('Jenis kas tidak ditemukan.');
    }
    // Status: lunas bila nominal >= jumlah jenis kas, selain itu sebagian.
    final String status = amount >= cashType.amount
        ? PaymentStatus.lunas
        : PaymentStatus.sebagian;

    final String code = await nextPaymentCode(year, month);
    final String now = DateTime.now().toIso8601String();
    final PaymentPeriod period = PaymentPeriod.forDate(
      periodStart ?? DateTime.parse(paidDate),
      cashType.frequency,
    );
    final String? periodStartKey = cashType.frequency == PaymentFrequency.sekali
        ? null
        : PaymentPeriod.dateKey(periodStart ?? period.start);
    final String? periodEndKey = cashType.frequency == PaymentFrequency.sekali
        ? null
        : PaymentPeriod.dateKey(periodEnd ?? period.end);
    final int id = await _db.insert(DBHelper.tblPayments, <String, Object?>{
      'payment_code': code,
      'student_id': studentId,
      'cash_type_id': cashTypeId,
      'amount': amount,
      'month': month,
      'year': year,
      'period_start': periodStartKey,
      'period_end': periodEndKey,
      'paid_date': paidDate,
      'payment_method': paymentMethod,
      'status': status,
      'note': note,
      'recorded_by': recordedBy,
      'created_at': now,
      'updated_at': now,
    });
    final PaymentModel? saved = await getById(id);
    if (saved == null) {
      throw StateError('Gagal menyimpan pembayaran.');
    }
    return saved;
  }

  /// Daftar pembayaran dengan filter periode (bulan/tahun) & kelas.
  Future<List<PaymentModel>> list({int? year, int? month, int? classId}) async {
    final List<String> where = <String>['1=1'];
    final List<Object?> args = <Object?>[];
    if (year != null) {
      where.add('p.year = ?');
      args.add(year);
    }
    if (month != null) {
      where.add('p.month = ?');
      args.add(month);
    }
    if (classId != null) {
      where.add('s.class_id = ?');
      args.add(classId);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery('''
      SELECT p.*, s.name AS student_name, s.nis AS student_nis,
             c.name AS class_name, ct.name AS cash_type_name,
             ct.frequency AS cash_type_frequency,
             u.full_name AS officer_name
      FROM ${DBHelper.tblPayments} p
      JOIN ${DBHelper.tblStudents} s ON s.id = p.student_id
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblCashTypes} ct ON ct.id = p.cash_type_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = p.recorded_by
      WHERE ${where.join(' AND ')}
      ORDER BY p.paid_date DESC, p.id DESC
      ''', args);
    return rows.map(PaymentModel.fromMap).toList();
  }

  /// Detail satu pembayaran (dengan data siswa, kelas, jenis kas, petugas).
  Future<PaymentModel?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT p.*, s.name AS student_name, s.nis AS student_nis,
             c.name AS class_name, ct.name AS cash_type_name,
             ct.frequency AS cash_type_frequency,
             u.full_name AS officer_name
      FROM ${DBHelper.tblPayments} p
      JOIN ${DBHelper.tblStudents} s ON s.id = p.student_id
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblCashTypes} ct ON ct.id = p.cash_type_id
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = p.recorded_by
      WHERE p.id = ?
      LIMIT 1
      ''',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return PaymentModel.fromMap(rows.first);
  }

  /// Hapus permanen satu transaksi pembayaran.
  Future<void> delete(int id) async {
    await _db.delete(
      DBHelper.tblPayments,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Batalkan (void) pembayaran → status batal + alasan wajib.
  Future<void> voidPayment(int id, {required String reason}) async {
    await _db.update(
      DBHelper.tblPayments,
      <String, Object?>{
        'status': PaymentStatus.batal,
        'void_reason': reason.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Total nominal pembayaran pada periode tertentu.
  /// Pembayaran berstatus batal tidak ikut dihitung.
  Future<int> sumPeriod({int? year, int? month, int? classId}) async {
    final List<String> where = <String>["status != '${PaymentStatus.batal}'"];
    final List<Object?> args = <Object?>[];
    if (year != null) {
      where.add('year = ?');
      args.add(year);
    }
    if (month != null) {
      where.add('month = ?');
      args.add(month);
    }
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblPayments} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Hitung besaran kewajiban untuk satu jenis kas pada jangka waktu tertentu.
  /// Frekuensi menentukan berapa kali nominal harus dibayar dalam rentang
  /// tersebut. Contoh: mingguan = 1 kali per minggu, semester = 1 kali per
  /// semester, tahunan = 1 kali per tahun.
  int owedForCashTypeInRange(
    CashTypeModel cashType, {
    required DateTime start,
    required DateTime end,
  }) {
    final int occurrences = _countOccurrencesForFrequency(
      cashType.frequency,
      start: start,
      end: end,
    );
    return cashType.amount * occurrences;
  }

  int _countOccurrencesForFrequency(
    String frequency, {
    required DateTime start,
    required DateTime end,
  }) {
    final int daySpan = end.difference(start).inDays + 1;
    switch (frequency) {
      case PaymentFrequency.harian:
        return daySpan;
      case PaymentFrequency.mingguan:
        {
          final Set<String> weeks = <String>{};
          DateTime weekStart = DateTime(
            start.year,
            start.month,
            start.day - (start.weekday - 1),
          );
          while (!weekStart.isAfter(end)) {
            weeks.add('${weekStart.year}-${weekStart.month}-${weekStart.day}');
            weekStart = weekStart.add(const Duration(days: 7));
          }
          return weeks.length;
        }
      case PaymentFrequency.bulanan:
        {
          final Set<String> months = <String>{};
          DateTime cursor = DateTime(start.year, start.month, 1);
          final DateTime limit = DateTime(end.year, end.month, 1);
          while (!cursor.isAfter(limit)) {
            months.add(
              '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}',
            );
            cursor = DateTime(cursor.year, cursor.month + 1, 1);
          }
          return months.length;
        }
      case PaymentFrequency.semester:
        {
          final Set<String> semesters = <String>{};
          DateTime cursor = DateTime(start.year, start.month <= 6 ? 1 : 7, 1);
          final DateTime limit = DateTime(end.year, end.month <= 6 ? 1 : 7, 1);
          while (!cursor.isAfter(limit)) {
            semesters.add('${cursor.year}-${cursor.month <= 6 ? '1' : '2'}');
            cursor = DateTime(cursor.year, cursor.month + 6, 1);
          }
          return semesters.length;
        }
      case PaymentFrequency.tahunan:
        {
          final Set<String> years = <String>{};
          DateTime cursor = DateTime(start.year, 1, 1);
          final DateTime limit = DateTime(end.year, 1, 1);
          while (!cursor.isAfter(limit)) {
            years.add('${cursor.year}');
            cursor = DateTime(cursor.year + 1, 1, 1);
          }
          return years.length;
        }
      case PaymentFrequency.sekali:
      default:
        return 1;
    }
  }

  /// Status satu siswa pada satu periode UNTUK SATU JENIS KAS TERPILIH.
  /// Untuk alur pembayaran, nominal jenis kas adalah tagihan per satu kali
  /// pembayaran pada periode yang dipilih (mis. bulan ini). Jadi kita tidak
  /// mengalikan nominal dengan jumlah hari/minggu/semester di bulan itu.
  Future<PeriodStatus> monthlyStatus(
    int studentId,
    int month,
    int year, {
    required int cashTypeId,
    DateTime? paidDate,
  }) async {
    final CashTypeModel? cashType = await getCashType(cashTypeId);
    if (cashType == null) {
      throw StateError('Jenis kas tidak ditemukan.');
    }
    return periodStatus(
      studentId,
      cashTypeId: cashTypeId,
      period: PaymentPeriod.forDate(
        paidDate ?? DateTime(year, month),
        cashType.frequency,
      ),
    );
  }

  Future<PeriodStatus> periodStatus(
    int studentId, {
    required int cashTypeId,
    required PaymentPeriod period,
  }) async {
    final CashTypeModel? cashType = await getCashType(cashTypeId);
    if (cashType == null) {
      throw StateError('Jenis kas tidak ditemukan.');
    }
    final int owed = cashType.amount;
    final bool isOneTime = cashType.frequency == PaymentFrequency.sekali;
    final String periodFilter = isOneTime
        ? ''
        : 'AND period_start = ? AND period_end = ?';
    final List<Object?> args = <Object?>[
      studentId,
      cashTypeId,
      if (!isOneTime) ...<Object?>[
        PaymentPeriod.dateKey(period.start),
        PaymentPeriod.dateKey(period.end),
      ],
    ];
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM ${DBHelper.tblPayments} '
      'WHERE student_id = ? AND cash_type_id = ? $periodFilter '
      "AND status != '${PaymentStatus.batal}'",
      args,
    );
    final int paid = Sqflite.firstIntValue(rows) ?? 0;
    return _buildPeriodStatus(owed, paid);
  }

  /// Daftar tunggakan siswa aktif pada periode terpilih untuk SATU JENIS
  /// KAS TERPILIH. Siswa tetap muncul walau belum membayar (paid = 0),
  /// dan kewajiban mengikuti frekuensi kas yang dipilih.
  Future<List<TunggakanItem>> listTunggakan({
    int? month,
    int? year,
    DateTime? periodStart,
    DateTime? periodEnd,
    int? classId,
    int? majorId,
    int? cashTypeId,
  }) async {
    final List<String> where = <String>[
      's.is_active = 1',
      "s.status = 'aktif'",
    ];
    final List<Object?> args = <Object?>[];
    if (classId != null) {
      where.add('s.class_id = ?');
      args.add(classId);
    }
    if (majorId != null) {
      where.add('COALESCE(s.major_id, c.major_id) = ?');
      args.add(majorId);
    }
    final CashTypeModel? cashType = cashTypeId == null
        ? null
        : await getCashType(cashTypeId);
    final int owed = cashType?.amount ?? 0;
    final bool isOneTime = cashType?.frequency == PaymentFrequency.sekali;
    final String paymentPeriodFilter = isOneTime
        ? ''
        : periodStart != null && periodEnd != null
        ? 'AND p.period_start = ? AND p.period_end = ?'
        : 'AND p.month = ? AND p.year = ?';
    final List<Object?> paymentPeriodArgs = isOneTime
        ? <Object?>[]
        : periodStart != null && periodEnd != null
        ? <Object?>[
            PaymentPeriod.dateKey(periodStart),
            PaymentPeriod.dateKey(periodEnd),
          ]
        : <Object?>[month, year];

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT s.id AS student_id, s.nis, s.name, c.name AS class_name,
             m.name AS major_name,
             COALESCE(SUM(p.amount), 0) AS paid
      FROM ${DBHelper.tblStudents} s
      LEFT JOIN ${DBHelper.tblClasses} c ON c.id = s.class_id
      LEFT JOIN ${DBHelper.tblMajors} m ON m.id = COALESCE(s.major_id, c.major_id)
      LEFT JOIN ${DBHelper.tblPayments} p ON p.student_id = s.id
        $paymentPeriodFilter
        AND p.cash_type_id = ?
        AND p.status != '${PaymentStatus.batal}'
      WHERE ${where.join(' AND ')}
      GROUP BY s.id
      ORDER BY c.level ASC, c.name ASC, s.name ASC
      ''',
      <Object?>[...paymentPeriodArgs, cashTypeId, ...args],
    );

    return rows.map((Map<String, Object?> r) {
      final int paid = (r['paid'] as int?) ?? 0;
      final PeriodStatus st = _buildPeriodStatus(owed, paid);
      return TunggakanItem(
        studentId: r['student_id'] as int,
        nis: r['nis'] as String,
        name: r['name'] as String,
        className: r['class_name'] as String?,
        majorName: r['major_name'] as String?,
        owed: st.owed,
        paid: st.paid,
        sisa: st.sisa,
        status: st.status,
      );
    }).toList();
  }

  /// Detail satu jenis kas berdasarkan id.
  Future<CashTypeModel?> getCashType(int id) async {
    final Map<String, Object?>? row = await _db.queryOne(
      DBHelper.tblCashTypes,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return row == null ? null : CashTypeModel.fromMap(row);
  }

  PeriodStatus _buildPeriodStatus(int owed, int paid) {
    final int sisa = paid >= owed ? 0 : owed - paid;
    String status;
    if (owed <= 0 || paid >= owed) {
      status = PaymentStatus.lunas;
    } else if (paid > 0) {
      status = PaymentStatus.sebagian;
    } else {
      status = PaymentStatus.belum;
    }
    return PeriodStatus(owed: owed, paid: paid, sisa: sisa, status: status);
  }
}
