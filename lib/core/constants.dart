import 'package:flutter/material.dart';

/// Konstanta global aplikasi Kas Bintang Nusantara.
class AppConstants {
  AppConstants._();

  static const String appName = 'Kas Bintang Nusantara';
  static const String appTagline = 'Bendahara SMK Bintang Nusantara';
  static const String appVersion = '1.0.3';

  // Nama & versi database
  static const String dbName = 'kas_bintang_nusantara.db';
  static const int dbVersion = 3;

  // Kredensial default bendahara (dibuat otomatis saat DB pertama kali dibuat)
  static const String defaultUsername = 'bendahara';
  static const String defaultPassword = 'bintang123';
  static const String defaultFullName = 'Bendahara SMK Bintang Nusantara';
  static const String defaultNip = '-';
}

/// Batas rentang tanggal & tahun yang dipakai seluruh filter aplikasi.
class AppDateRange {
  AppDateRange._();

  /// Tahun paling tua yang bisa dipilih di filter.
  static const int minYear = 2000;

  /// Tahun paling baru yang bisa dipilih di filter.
  static const int maxYear = 2100;

  static DateTime get minDate => DateTime(minYear);
  static DateTime get maxDate => DateTime(maxYear, 12, 31);

  /// Batasi sembarang tanggal agar tetap di dalam [minDate]..[maxDate].
  static DateTime clamp(DateTime d) {
    if (d.isBefore(minDate)) return minDate;
    if (d.isAfter(maxDate)) return maxDate;
    return DateTime(d.year, d.month, d.day);
  }

  /// Daftar tahun siap pakai untuk dropdown filter (urut menaik).
  ///
  /// Mengandung semua tahun dari [minYear] sampai [maxYear] supaya tahun
  /// jauh ke depan (sampai 2100) tetap bisa dipilih, bukan hanya beberapa
  /// tahun ke depan dari sekarang.
  static List<int> get semuaTahun =>
      <int>[for (int y = minYear; y <= maxYear; y++) y];

  /// Tahun sekitar [anchor] untuk mengisi awal dropdown (tahun berjalan).
  static List<int> tahunSekitar(
    int anchor, {
    int sebelum = 5,
    int sesudah = 1,
  }) {
    return <int>[
      for (int y = anchor - sebelum; y <= anchor + sesudah; y++)
        if (y >= minYear && y <= maxYear) y,
    ];
  }
}

/// Palet warna tema aplikasi (mengikuti spesifikasi desain).
class AppColors {
  AppColors._();

  // Warna utama
  static const Color navy = Color(0xFF0A1F44);
  static const Color navySoft = Color(0xFF14264F);

  // Aksen
  static const Color orange = Color(0xFFE88A0C);
  static const Color teal = Color(0xFF3FA796);
  static const Color blue = Color(0xFF2A6FDB);
  static const Color cream = Color(0xFFF2A08A);

  // Background & netral
  static const Color background = Color(0xFFF7F7F9);
  static const Color card = Colors.white;

  // Teks
  static const Color textPrimary = Color(0xFF0A1F44);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFEDEFF3);

  // Status
  static const Color success = teal;
  static const Color danger = Color(0xFFDC4B4B);
  static const Color warning = orange;
}
