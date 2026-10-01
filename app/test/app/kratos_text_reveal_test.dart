import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_motion.dart';

void main() {
  testWidgets('KratosTextReveal preserves text and completes its entrance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KratosTextReveal(child: Text('Existing KRATOS text')),
        ),
      ),
    );

    expect(find.text('Existing KRATOS text'), findsOneWidget);
    final initialOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(initialOpacity, lessThan(1));
    await tester.pump(const Duration(milliseconds: 120));
    final enteringOpacity = tester
        .widget<Opacity>(find.byType(Opacity))
        .opacity;
    expect(enteringOpacity, greaterThan(initialOpacity));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Existing KRATOS text'), findsOneWidget);
  });
}
