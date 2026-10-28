import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/screens/settings/bantuan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel launcherChannel = MethodChannel(
    'plugins.flutter.io/url_launcher',
  );
  String? launchedUrl;

  setUp(() {
    launchedUrl = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (MethodCall call) async {
          expect(call.method, 'launch');
          launchedUrl = call.arguments['url'] as String;
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  testWidgets('Kirim Email membuka draft dengan alamat dan template bantuan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BantuanScreen()));

    await tester.scrollUntilVisible(
      find.text('Kirim Email'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kirim Email'));
    await tester.pumpAndSettle();

    expect(launchedUrl, isNotNull);
    final Uri draft = Uri.parse(launchedUrl!);
    expect(draft.scheme, 'mailto');
    expect(draft.path, 'ranggawaridat@gmail.com');
    expect(
      draft.queryParameters['subject'],
      'Bantuan Aplikasi Kas Bintang Nusantara',
    );
    expect(draft.queryParameters['body'], contains('Kendala atau pertanyaan:'));
    expect(
      draft.queryParameters['body'],
      contains('Langkah yang sudah dicoba:'),
    );
  });
}
