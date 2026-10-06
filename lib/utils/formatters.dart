import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Utilitas format teks, mata uang, dan tanggal.
class Formatters {
  Formatters._();

  static bool _initialized = false;

  /// Pastikan data simbol tanggal untuk locale 'id_ID' dimuat (dipanggil otomatis).
  static void _ensureInitialized() {
    if (_initialized) return;
    initializeDateFormatting('id_ID', null);
    _initialized = true;
  }

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static DateFormat _date() {
    _ensureInitialized();
    return DateFormat('d MMMM yyyy', 'id_ID');
  }

  static DateFormat _dateShort() {
    _ensureInitialized();
    return DateFormat('dd/MM/yyyy', 'id_ID');
  }

  static DateFormat _dateTime() {
    _ensureInitialized();
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  }

  static DateFormat _monthFull() {
    _ensureInitialized();
    return DateFormat.MMMM('id_ID');
  }

  /// Format angka (tanpa simbol) → contoh: 12.500.000
  static String angka(int value) => NumberFormat.decimalPattern('id_ID').format(value);

  /// Format Rupiah → contoh: Rp 25.000
  static String rupiah(int value) => _rupiah.format(value);

  /// Format Rupiah tanpa desimal/simbol untuk PDF.
  static String rupiahPlain(int value) => angka(value);

  /// Tanggal penuh → 12 Maret 2026
  static String tanggal(DateTime date) => _date().format(date);

  /// Tanggal dari String ISO → 12 Maret 2026
  static String tanggalIso(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final DateTime? date = DateTime.tryParse(iso);
    return date == null ? iso : _date().format(date);
  }

  /// Tanggal pendek → 12/03/2026
  static String tanggalPendekIso(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final DateTime? date = DateTime.tryParse(iso);
    return date == null ? iso : _dateShort().format(date);
  }

  /// Tanggal + jam → 12 Mar 2026, 14:30
  static String tanggalWaktuIso(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final DateTime? date = DateTime.tryParse(iso);
    return date == null ? iso : _dateTime().format(date);
  }

  /// Nama bulan Indonesia (1-12).
  static String namaBulan(int month) {
    return _monthFull().format(DateTime(2026, month, 1));
  }

  /// Nama bulan pendek (Jan, Feb, ...).
  static String namaBulanPendek(int month) {
    _ensureInitialized();
    return DateFormat.MMM('id_ID').format(DateTime(2026, month, 1));
  }
}

/// Generator kode transaksi unik.
class CodeGenerator {
  CodeGenerator._();

  /// Kode pembayaran → BR/{tahun}-{bln}/{urutan6}
  static String payment(String prefix, int sequence) {
    final DateTime now = DateTime.now();
    final String seq = sequence.toString().padLeft(6, '0');
    return '$prefix/${now.year}-${now.month.toString().padLeft(2, '0')}/$seq';
  }
}