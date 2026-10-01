import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/number_pop_in.dart';

void main() {
  testWidgets('KratosNumberPopIn preserves the displayed value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KratosNumberPopIn('1,250 XP'))),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text(' XP'), findsNothing);

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byType(KratosNumberPopIn), findsOneWidget);
  });

  testWidgets('KratosNumberPopIn respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: KratosNumberPopIn('42'))),
      ),
    );

    expect(find.text('42'), findsOneWidget);
  });
}
