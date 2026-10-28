import 'cash_type_model.dart';
import '../utils/formatters.dart';

class PaymentPeriod {
  final DateTime start;
  final DateTime end;

  const PaymentPeriod({required this.start, required this.end});

  factory PaymentPeriod.forDate(DateTime date, String frequency) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    switch (frequency) {
      case PaymentFrequency.harian:
      case PaymentFrequency.sekali:
        return PaymentPeriod(start: day, end: day);
      case PaymentFrequency.mingguan:
        final DateTime start = day.subtract(Duration(days: day.weekday - 1));
        return PaymentPeriod(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      case PaymentFrequency.bulanan:
        return PaymentPeriod(
          start: DateTime(day.year, day.month),
          end: DateTime(day.year, day.month + 1, 0),
        );
      case PaymentFrequency.semester:
        final int firstMonth = day.month <= 6 ? 1 : 7;
        return PaymentPeriod(
          start: DateTime(day.year, firstMonth),
          end: DateTime(day.year, firstMonth + 6, 0),
        );
      case PaymentFrequency.tahunan:
        return PaymentPeriod(
          start: DateTime(day.year),
          end: DateTime(day.year + 1, 1, 0),
        );
      default:
        return PaymentPeriod(start: day, end: day);
    }
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String label({
    required String frequency,
    required String? start,
    required String? end,
    required int fallbackMonth,
    required int fallbackYear,
  }) {
    if (frequency == PaymentFrequency.sekali) return 'Sekali';
    final DateTime? periodStart = start == null
        ? null
        : DateTime.tryParse(start);
    final DateTime? periodEnd = end == null ? null : DateTime.tryParse(end);
    if (periodStart == null || periodEnd == null) {
      return '${Formatters.namaBulan(fallbackMonth)} $fallbackYear';
    }
    switch (frequency) {
      case PaymentFrequency.harian:
        return Formatters.tanggal(periodStart);
      case PaymentFrequency.mingguan:
        return '${Formatters.tanggalPendekIso(start)} - '
            '${Formatters.tanggalPendekIso(end)}';
      case PaymentFrequency.bulanan:
        return '${Formatters.namaBulan(periodStart.month)} ${periodStart.year}';
      case PaymentFrequency.semester:
        return 'Semester ${periodStart.month == 1 ? 1 : 2} ${periodStart.year}';
      case PaymentFrequency.tahunan:
        return '${periodStart.year}';
      default:
        return '${Formatters.namaBulan(fallbackMonth)} $fallbackYear';
    }
  }
}
