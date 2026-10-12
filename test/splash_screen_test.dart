import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/screens/splash/splash_screen.dart';

/// Uji splash animasi: logo & nama aplikasi tampil di tengah animasi,
/// lalu onFinished dipanggil setelah fade-out selesai.
void main() {
  testWidgets('splash menampilkan logo dan nama aplikasi lalu selesai', (
    WidgetTester tester,
  ) async {
    bool selesai = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(onFinished: () => selesai = true),
      ),
    );

    // Tengah animasi (± 2 detik): logo dan nama aplikasi harus tampil.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    expect(find.text('Kas Bintang Nusantara'), findsOneWidget);

    // Lewati sisa animasi (durasi total 2,8 detik) sampai fade-out selesai.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(selesai, isTrue, reason: 'onFinished harus dipanggil setelah animasi');
  });

  testWidgets('onFinished tidak dipanggil sebelum animasi selesai', (
    WidgetTester tester,
  ) async {
    bool selesai = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(onFinished: () => selesai = true),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1000));
    expect(selesai, isFalse);

    await tester.pump(const Duration(milliseconds: 3000));
    expect(selesai, isTrue);
  });
}
