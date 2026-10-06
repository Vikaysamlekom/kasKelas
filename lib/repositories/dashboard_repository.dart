import '../database/db_helper.dart';

/// Ringkasan satu baris progres pembayaran per kelas.
class ClassProgress {
  final int classId;
  final String className;
  final int totalStudents;
  final int paidStudents;
  final double percent;

  const ClassProgress({
    required this.classId,
    required this.className,
    required this.totalStudents,
    required this.paidStudents,
    required this.percent,
  });
}

/// Ringkasan saldo & statistik untuk Dashboard.
class DashboardSummary {
  final int saldo; // total pemasukan - total pengeluaran
  final int totalPemasukan;
  final int totalPengeluaran;
  final int pemasukanBulanIni;
  final int pengeluaranBulanIni;
  final int transaksiHariIni;

  const DashboardSummary({
    required this.saldo,
    required this.totalPemasukan,
    required this.totalPengeluaran,
    required this.pemasukanBulanIni,
    required this.pengeluaranBulanIni,
    required this.transaksiHariIni,
  });
}

/// Repository data untuk Dashboard (saldo, statistik, progres kelas).
class DashboardRepository {
  final DBHelper _db = DBHelper.instance;

  /// Ringkasan utama dashboard.
  Future<DashboardSummary> getSummary() async {
    final int totalPemasukan = await _db.sum(
      DBHelper.tblPayments,
      'amount',
      where: "status != 'batal'",
    );
    final int totalPengeluaran = await _db.sum(
      DBHelper.tblExpenses,
      'amount',
      where: "status != 'batal'",
    );

    final DateTime now = DateTime.now();
    final int pemasukanBulanIni = await _db.sum(
      DBHelper.tblPayments,
      'amount',
      where: 'year = ? AND month = ? AND status != ?',
      whereArgs: <Object?>[now.year, now.month, 'batal'],
    );
    final int pengeluaranBulanIni = await _db.sum(
      DBHelper.tblExpenses,
      'amount',
      where: "status != 'batal' AND substr(expense_date, 1, 7) = ?",
      whereArgs: <Object?>[now.toIso8601String().substring(0, 7)],
    );

    final int transaksiHariIni = await _db.count(
      DBHelper.tblPayments,
      where: 'substr(paid_date, 1, 10) = ?',
      whereArgs: <Object?>[now.toIso8601String().substring(0, 10)],
    );

    return DashboardSummary(
      saldo: totalPemasukan - totalPengeluaran,
      totalPemasukan: totalPemasukan,
      totalPengeluaran: totalPengeluaran,
      pemasukanBulanIni: pemasukanBulanIni,
      pengeluaranBulanIni: pengeluaranBulanIni,
      transaksiHariIni: transaksiHariIni,
    );
  }

  /// Progres pembayaran per kelas untuk bulan/ tahun tertentu.
  Future<List<ClassProgress>> getClassProgress({int? year, int? month}) async {
    final DateTime now = DateTime.now();
    final int y = year ?? now.year;
    final int m = month ?? now.month;

    final List<Map<String, Object?>> classes = await _db.query(
      DBHelper.tblClasses,
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );

    final List<ClassProgress> result = <ClassProgress>[];

    for (final Map<String, Object?> cls in classes) {
      final int classId = cls['id'] as int;
      final String className = cls['name'] as String;

      final int totalStudents = await _db.count(
        DBHelper.tblStudents,
        where: 'class_id = ? AND status = ? AND is_active = 1',
        whereArgs: <Object?>[classId, 'aktif'],
      );

      final List<Map<String, Object?>> paidRows = await _db.rawQuery(
        'SELECT DISTINCT s.id FROM students s '
        'INNER JOIN payments p ON p.student_id = s.id '
        'WHERE s.class_id = ? AND p.year = ? AND p.month = ? '
        'AND p.status IN (?, ?) AND s.status = ? AND s.is_active = 1',
        <Object?>[classId, y, m, 'lunas', 'sebagian', 'aktif'],
      );

      final int paidStudents = paidRows.length;

      result.add(
        ClassProgress(
          classId: classId,
          className: className,
          totalStudents: totalStudents,
          paidStudents: paidStudents,
          percent: totalStudents == 0
              ? 0
              : (paidStudents / totalStudents * 100).clamp(0, 100),
        ),
      );
    }

    result.sort((ClassProgress a, ClassProgress b) {
      return b.percent.compareTo(a.percent);
    });
    return result;
  }
}