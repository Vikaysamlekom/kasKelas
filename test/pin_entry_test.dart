import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/widgets/pin_entry.dart';

void main() {
  testWidgets('PinDots starts at the minimum PIN length and grows as needed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PinDots(length: 0)),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(6));

    await tester.pumpWidget(
      const MaterialApp(home: PinDots(length: 7)),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(7));

    await tester.pumpWidget(
      const MaterialApp(home: PinDots(length: 8)),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(8));
  });
}
