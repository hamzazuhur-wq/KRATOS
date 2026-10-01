import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_dropdown.dart';

void main() {
  testWidgets('KratosDropdown morphs open and closed from its trigger', (
    tester,
  ) async {
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => KratosDropdown<String>(
                value: value,
                hint: 'Choose',
                items: const [
                  KratosDropdownItem(value: 'one', label: 'First'),
                  KratosDropdownItem(value: 'two', label: 'Second'),
                ],
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Second'), findsNothing);
    await tester.tap(find.text('Choose'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Second'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
  });
}
