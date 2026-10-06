import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/constants.dart';

/// Uji rentang tanggal & tahun filter.
///
/// Permintaan pengguna: filter tanggal di aplikasi harus bisa menjangkau
/// sampai TAHUN 2100 (sebelumnya hanya "sekitar tahun sekarang + 1").
void main() {
  group('AppDateRange - batas bawah & atas', () {
    test('batas tahun adalah 2000 sampai 2100', () {
      expect(AppDateRange.minYear, 2000);
      expect(AppDateRange.maxYear, 2100);
    });

    test('minDate dan maxDate berada di batas yang benar', () {
      expect(AppDateRange.minDate, DateTime(2000, 1, 1));
      expect(AppDateRange.maxDate, DateTime(2100, 12, 31));
    });

    test('clamp menahan tanggal terlalu tua ke 2000-01-01', () {
      expect(AppDateRange.clamp(DateTime(1990, 5, 10)), DateTime(2000, 1, 1));
    });

    test('clamp menahan tanggal terlalu baru ke 2100-12-31', () {
      expect(AppDateRange.clamp(DateTime(2200, 5, 10)), DateTime(2100, 12, 31));
    });

    test('clamp mempertahankan tanggal yang sudah di dalam rentang', () {
      expect(AppDateRange.clamp(DateTime(2026, 9, 30)), DateTime(2026, 9, 30));
      expect(AppDateRange.clamp(DateTime(2100, 1, 1)), DateTime(2100, 1, 1));
    });
  });

  group('Daftar tahun filter', () {
    test('menghasilkan seluruh tahun 2000 sampai 2100', () {
      final List<int> years = AppDateRange.semuaTahun;
      expect(years.length, 2100 - 2000 + 1);
      expect(years.first, 2000);
      expect(years.last, 2100);
      expect(years.contains(2026), isTrue);
      expect(years.contains(2100), isTrue);
    });

    test('daftar tahun terurut menaik', () {
      final List<int> years = AppDateRange.semuaTahun;
      for (int i = 1; i < years.length; i++) {
        expect(years[i], greaterThan(years[i - 1]));
      }
    });

    test('tahunSekitar dibatasi ke rentang yang sah', () {
      final List<int> tahun = AppDateRange.tahunSekitar(2026);
      expect(tahun.first, 2021);
      expect(tahun.last, 2027);
      expect(tahun.every((int y) => y >= 2000 && y <= 2100), isTrue);
    });

    test('tahunSekitar tidak keluar batas bawah maupun atas', () {
      expect(AppDateRange.tahunSekitar(2001, sebelum: 5, sesudah: 1).first, 2000);
      expect(
        AppDateRange.tahunSekitar(2099, sebelum: 5, sesudah: 5).last,
        2100,
      );
    });
  });
}
