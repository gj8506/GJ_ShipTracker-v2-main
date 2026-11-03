import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/returns/presentation/create_return_screen.dart';

Widget _buildScreen() {
  return const ProviderScope(
    child: MaterialApp(home: CreateReturnScreen()),
  );
}

/// Picks a value on the Defect Category dropdown (the third dropdown).
Future<void> _selectDefectReason(WidgetTester tester, String reason) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>).at(2))
      .onChanged!(reason);
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.text('Submit Return Ticket');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('photo evidence is required and marked as such', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    expect(find.text('Photo Evidence *'), findsOneWidget);
    expect(find.text('Specify the Other Issue *'), findsNothing);
  });

  testWidgets('"Other Issues" reveals a required specification field',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await _selectDefectReason(tester, 'Other Issues');
    expect(find.text('Specify the Other Issue *'), findsOneWidget);

    await _selectDefectReason(tester, 'Damaged in Transit');
    expect(find.text('Specify the Other Issue *'), findsNothing);
  });

  testWidgets('submitting a blank ticket fails on every required field',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await _tapSubmit(tester);

    expect(find.text('Enter tracking number'), findsOneWidget);
    expect(find.text('Customer name is required'), findsOneWidget);
    expect(find.text('Enter items or plate specs'), findsOneWidget);
    expect(find.text('Enter defect description'), findsOneWidget);
    expect(
        find.text('Attach at least one photo of the defect'), findsOneWidget);
  });

  testWidgets('a filled ticket without a photo is still rejected',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Original Tracking Number *'),
      'SPX4572829R9E88',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer / Buyer Name *'),
      'Maria Santos',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motorcycle Plate Specifications *'),
      'White plate, embossed, 4x7',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Defect Description / Notes *'),
      'Cracked corner on the plate',
    );

    await _tapSubmit(tester);

    expect(
        find.text('Attach at least one photo of the defect'), findsOneWidget);
    // The filled fields no longer report errors.
    expect(find.text('Enter tracking number'), findsNothing);
    expect(find.text('Customer name is required'), findsNothing);
    expect(find.text('Enter defect description'), findsNothing);
  });

  testWidgets('"Other Issues" cannot be submitted without its specification',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await _selectDefectReason(tester, 'Other Issues');
    await _tapSubmit(tester);

    expect(find.text('Describe the other issue'), findsOneWidget);
  });
}
