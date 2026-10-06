/// Jenis periode pelaporan.
enum PeriodeJenis {
  hariIni,
  mingguIni,
  bulanIni,
  bulanLalu,
  semester,
  tahun,
  custom,
}

/// Kelompok/agregasi baris laporan.
enum KelompokLaporan {
  perTanggal,
  perBulan,
  perKelas,
  perJurusan,
  perJenisKas,
  perKategori,
}

/// Rentang tanggal laporan [start..end] inklusif.
class PeriodeLaporan {
  final DateTime start;
  final DateTime end;
  final String label;

  const PeriodeLaporan({
    required this.start,
    required this.end,
    required this.label,
  });

  /// Jumlah bulan pada rentang (untuk hitung tagihan siswa).
  int get bulanCount =>
      ((end.year - start.year) * 12 + (end.month - start.month) + 1);

  /// Kunci tanggal format 'yyyy-MM-dd' untuk filter SQL (substr ISO).
  String get startKey => _dateKey(start);

  String get endKey => _dateKey(end);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String kunciBulan(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String kunciHari(DateTime d) => _dateKey(d);

  /// Bangun periode berdasarkan jenis. `a`/`b` dipakai hanya saat [custom].
  static PeriodeLaporan dari(
    PeriodeJenis jenis, {
    DateTime? a,
    DateTime? b,
  }) {
    final DateTime now = DateTime.now();
    final int y = now.year;
    final int m = now.month;
    final int d = now.day;

    switch (jenis) {
      case PeriodeJenis.hariIni:
        return PeriodeLaporan(
          start: DateTime(y, m, d),
          end: DateTime(y, m, d),
          label: 'Hari ini',
        );
      case PeriodeJenis.mingguIni:
        final DateTime monday =
            DateTime(y, m, d - (now.weekday - 1));
        return PeriodeLaporan(
          start: monday,
          end: DateTime(y, m, d),
          label: 'Minggu ini',
        );
      case PeriodeJenis.bulanIni:
        return PeriodeLaporan(
          start: DateTime(y, m, 1),
          end: DateTime(y, m + 1, 0),
          label: 'Bulan ini',
        );
      case PeriodeJenis.bulanLalu:
        final int py = m == 1 ? y - 1 : y;
        final int pm = m == 1 ? 12 : m - 1;
        return PeriodeLaporan(
          start: DateTime(py, pm, 1),
          end: DateTime(py, pm + 1, 0),
          label: 'Bulan lalu',
        );
      case PeriodeJenis.semester:
        if (m <= 6) {
          return PeriodeLaporan(
            start: DateTime(y, 1, 1),
            end: DateTime(y, 6, 30),
            label: 'Semester 1 $y',
          );
        }
        return PeriodeLaporan(
          start: DateTime(y, 7, 1),
          end: DateTime(y, 12, 31),
          label: 'Semester 2 $y',
        );
      case PeriodeJenis.tahun:
        return PeriodeLaporan(
          start: DateTime(y, 1, 1),
          end: DateTime(y, 12, 31),
          label: 'Tahun $y',
        );
      case PeriodeJenis.custom:
        final DateTime s = a ?? now;
        final DateTime e = (b ?? now).isBefore(s) ? s : (b ?? now);
        return PeriodeLaporan(
          start: DateTime(s.year, s.month, s.day),
          end: DateTime(e.year, e.month, e.day),
          label:
              '${_dateKey(s)} s.d. ${_dateKey(e)}',
        );
    }
  }
}

/// Satu baris hasil agregasi laporan (mis. per bulan / per kelas).
class LaporanBaris {
  final String label;
  final int jumlah; // jumlah transaksi / jumlah siswa
  final int nominal;

  const LaporanBaris({
    required this.label,
    required this.jumlah,
    required this.nominal,
  });
}

/// Hasil laporan saldo: saldo awal, pemasukan, pengeluaran, saldo akhir.
class LaporanSaldo {
  final int saldoAwal;
  final int pemasukan;
  final int pengeluaran;
  final int saldoAkhir;

  const LaporanSaldo({
    required this.saldoAwal,
    required this.pemasukan,
    required this.pengeluaran,
    required this.saldoAkhir,
  });
}

/// Satu baris laporan pembayaran per siswa.
class LaporanPembayaranSiswa {
  final String nis;
  final String name;
  final String? className;
  final String? majorName;
  final int tagihan;
  final int bayar;
  final int tunggakan;
  final String status; // lunas / sebagian / belum

  const LaporanPembayaranSiswa({
    required this.nis,
    required this.name,
    this.className,
    this.majorName,
    required this.tagihan,
    required this.bayar,
    required this.tunggakan,
    required this.status,
  });
}

/// Opsi filter laporan (kelas / jurusan / jenis kas / kategori).
class LaporanFilter {
  final int? classId;
  final int? majorId;
  final int? cashTypeId;
  final int? categoryId;
  final String? statusSiswa;

  const LaporanFilter({
    this.classId,
    this.majorId,
    this.cashTypeId,
    this.categoryId,
    this.statusSiswa,
  });

  LaporanFilter copyWith({
    int? Function()? classId,
    int? Function()? majorId,
    int? Function()? cashTypeId,
    int? Function()? categoryId,
    String? Function()? statusSiswa,
  }) {
    return LaporanFilter(
      classId: classId != null ? classId() : this.classId,
      majorId: majorId != null ? majorId() : this.majorId,
      cashTypeId: cashTypeId != null ? cashTypeId() : this.cashTypeId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      statusSiswa: statusSiswa != null ? statusSiswa() : this.statusSiswa,
    );
  }
}