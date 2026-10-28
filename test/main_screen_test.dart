import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/providers/navigation_provider.dart';
import 'package:kas_bintang_nusantara/screens/main_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('swiping pages updates the selected navbar destination', (
    WidgetTester tester,
  ) async {
    final NavigationProvider navigation = NavigationProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NavigationProvider>.value(
        value: navigation,
        child: MaterialApp(
          home: MainScreen(
            pages: List<Widget>.generate(
              4,
              (int index) => Center(child: Text('Halaman $index')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Halaman 0'), findsOneWidget);
    expect(navigation.index, 0);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Halaman 1'), findsOneWidget);
    expect(navigation.index, 1);
  });

  testWidgets('selecting a navbar destination slides to its page', (
    WidgetTester tester,
  ) async {
    final NavigationProvider navigation = NavigationProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NavigationProvider>.value(
        value: navigation,
        child: MaterialApp(
          home: MainScreen(
            pages: List<Widget>.generate(
              4,
              (int index) => Center(child: Text('Halaman $index')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pembayaran'));
    await tester.pumpAndSettle();

    expect(find.text('Halaman 2'), findsOneWidget);
    expect(navigation.index, 2);
  });

  testWidgets('keeps visited page state and follows external navigation', (
    WidgetTester tester,
  ) async {
    final NavigationProvider navigation = NavigationProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NavigationProvider>.value(
        value: navigation,
        child: MaterialApp(
          home: MainScreen(
            pages: <Widget>[
              const _CounterPage(),
              for (int index = 1; index < 4; index++)
                Center(child: Text('Halaman $index')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('increment-counter')));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Jumlah: 1'), findsOneWidget);

    navigation.setIndex(3);
    await tester.pumpAndSettle();

    expect(find.text('Halaman 3'), findsOneWidget);
  });
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Jumlah: $_count'),
          ElevatedButton(
            key: const Key('increment-counter'),
            onPressed: () => setState(() => _count++),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}
