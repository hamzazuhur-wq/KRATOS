import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_motion.dart';

void main() {
  tearDown(() => KratosPageRoute.globalHeaderBuilder = null);

  testWidgets('shared header persists on a pushed material detail route', (
    tester,
  ) async {
    KratosPageRoute.globalHeaderBuilder = (_) => const Material(
      color: Colors.black,
      child: SizedBox(
        height: 64,
        child: Center(child: Text('KRATOS GLOBAL HEADER')),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  KratosMaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('Detail page')),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('KRATOS GLOBAL HEADER'), findsOneWidget);
    expect(find.text('Detail page'), findsOneWidget);
  });
}
