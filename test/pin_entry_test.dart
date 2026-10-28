import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/widgets/pin_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('PinKeypad gives haptic feedback when a key is tapped', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    final List<String> digits = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinKeypad(
            onDigit: digits.add,
            onBackspace: () {},
            onConfirm: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.pump();

    expect(digits, <String>['1']);
    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((MethodCall call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (MethodCall call) => call.arguments,
              'arguments',
              'HapticFeedbackType.lightImpact',
            ),
      ),
    );
  });
}
