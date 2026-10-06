import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/widgets/finance_summary.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _summary({
  int saldo = 15000000,
  int pemasukan = 20000000,
  int pengeluaran = 5000000,
  int transaksi = 7,
}) => FinanceSummary(
      sisaSaldo: saldo,
      totalPemasukan: pemasukan,
      totalPengeluaran: pengeluaran,
      pemasukanBulanIni: pemasukan,
      pengeluaranBulanIni: pengeluaran,
      transaksiHariIni: transaksi,
      periodeLabel: 'Sep 2026',
    );

void main() {
  group('FinanceSummary', () {
    testWidgets('menampilkan keempat metrik utama', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_summary()));
      await tester.pumpAndSettle();

      expect(find.text('SISA SALDO KAS'), findsOneWidget);
      expect(find.text('Total Pemasukan'), findsOneWidget);
      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('Transaksi Hari Ini'), findsOneWidget);
    });

    testWidgets('menampilkan nominal rupiah hasil hitung', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_summary(saldo: 15000000)));
      await tester.pumpAndSettle();

      // Saldo tampil di kartu hero.
      expect(find.text('Rp 15.000.000'), findsOneWidget);
      // Pemasukan & pengeluaran tampil di kartu metrik + mini stat hero.
      expect(find.text('Rp 20.000.000'), findsNWidgets(2));
      expect(find.text('Rp 5.000.000'), findsNWidgets(2));
    });

    testWidgets('menampilkan jumlah transaksi hari ini', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_summary(transaksi: 7)));
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
      expect(find.text('transaksi'), findsOneWidget);
    });

    testWidgets('aman saat seluruh data nol (tanpa divide-by-zero)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FinanceSummary(
            sisaSaldo: 0,
            totalPemasukan: 0,
            totalPengeluaran: 0,
            pemasukanBulanIni: 0,
            pengeluaranBulanIni: 0,
            transaksiHariIni: 0,
            periodeLabel: 'Sep 2026',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('belum ada'), findsOneWidget);
      expect(find.text('Belum ada pemasukan'), findsOneWidget);
      expect(find.text('Belum ada pengeluaran'), findsOneWidget);
    });

    testWidgets('rasio pengeluaran ter-clamp saat pengeluaran > pemasukan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FinanceSummary(
            sisaSaldo: -2000000,
            totalPemasukan: 1000000,
            totalPengeluaran: 3000000,
            pemasukanBulanIni: 1000000,
            pengeluaranBulanIni: 3000000,
            transaksiHariIni: 2,
            periodeLabel: 'Sep 2026',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Rasio ter-clamp ke 100% pengeluaran.
      expect(find.text('100% dari pemasukan'), findsOneWidget);
      expect(find.text('Minus'), findsOneWidget);
    });

    testWidgets('status "Aman" saat saldo positif', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_summary(saldo: 15000000)));
      await tester.pumpAndSettle();

      expect(find.text('Aman'), findsOneWidget);
    });

    testWidgets('animasi count-up dimulai dari nol lalu naik', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_summary(saldo: 15000000)));

      // Sebelum animasi berjalan semua nominal masih Rp 0.
      expect(find.text('Rp 0'), findsWidgets);
      expect(find.text('Rp 15.000.000'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Rp 15.000.000'), findsOneWidget);
      expect(find.text('Rp 0'), findsNothing);
    });

    testWidgets('nominal besar tidak memicu overflow layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FinanceSummary(
            sisaSaldo: 987654321098,
            totalPemasukan: 1500000000000,
            totalPengeluaran: 512345678912,
            pemasukanBulanIni: 1500000000000,
            pengeluaranBulanIni: 512345678912,
            transaksiHariIni: 128,
            periodeLabel: 'Sep 2026',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Rp 987.654.321.098'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
    });
  });
}
