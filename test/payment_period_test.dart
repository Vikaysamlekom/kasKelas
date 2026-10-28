import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/models/cash_type_model.dart';
import 'package:kas_bintang_nusantara/models/payment_period.dart';

void main() {
  test('weekly periods use Monday through Sunday', () {
    final PaymentPeriod period = PaymentPeriod.forDate(
      DateTime(2026, 3, 4),
      PaymentFrequency.mingguan,
    );

    expect(period.start, DateTime(2026, 3, 2));
    expect(period.end, DateTime(2026, 3, 8));
  });

  test('other recurring frequencies use calendar periods', () {
    final PaymentPeriod daily = PaymentPeriod.forDate(
      DateTime(2026, 3, 4),
      PaymentFrequency.harian,
    );
    final PaymentPeriod monthly = PaymentPeriod.forDate(
      DateTime(2026, 3, 4),
      PaymentFrequency.bulanan,
    );
    final PaymentPeriod firstSemester = PaymentPeriod.forDate(
      DateTime(2026, 3, 4),
      PaymentFrequency.semester,
    );
    final PaymentPeriod secondSemester = PaymentPeriod.forDate(
      DateTime(2026, 9, 4),
      PaymentFrequency.semester,
    );
    final PaymentPeriod annual = PaymentPeriod.forDate(
      DateTime(2026, 3, 4),
      PaymentFrequency.tahunan,
    );

    expect(daily.start, DateTime(2026, 3, 4));
    expect(daily.end, daily.start);
    expect(monthly.start, DateTime(2026, 3, 1));
    expect(monthly.end, DateTime(2026, 3, 31));
    expect(firstSemester.start, DateTime(2026, 1, 1));
    expect(firstSemester.end, DateTime(2026, 6, 30));
    expect(secondSemester.start, DateTime(2026, 7, 1));
    expect(secondSemester.end, DateTime(2026, 12, 31));
    expect(annual.start, DateTime(2026, 1, 1));
    expect(annual.end, DateTime(2026, 12, 31));
  });
}
