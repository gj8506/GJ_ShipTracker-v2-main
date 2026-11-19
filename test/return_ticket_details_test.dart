import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/returns/presentation/returns_providers.dart';
import 'package:gjandasher_shiptracker/features/returns/presentation/returns_screen.dart';

ReturnModel _ticket({
  String? customPlateDetails = 'White plate, embossed, 4x7',
  String? notes = 'Cracked corner on the plate',
  List<String> photoUrls = const [],
}) {
  return ReturnModel(
    id: 'ticket-123',
    trackingNumber: 'SPX4572829R9E88',
    platform: 'Shopee',
    customerName: 'Maria Santos',
    contactNumber: '09171234567',
    defectReason: 'Damaged in Transit',
    customPlateDetails: customPlateDetails,
    notes: notes,
    photoUrls: photoUrls,
    status: 'Pending',
    resolutionType: 'Replacement',
    createdAt: DateTime(2026, 11, 19, 9, 30),
  );
}

Future<void> _pumpReturns(
  WidgetTester tester, {
  List<ReturnModel>? tickets,
}) async {
  final container = ProviderContainer(
    overrides: [
      returnsStreamProvider.overrideWith(
        (ref) => Stream.value(tickets ?? [_ticket()]),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReturnsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds text inside the open detail sheet, ignoring the card behind it.
Finder _inSheet(String text) {
  return find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text(text),
  );
}

void main() {
  testWidgets('return ticket card is tappable and shows every detail field',
      (tester) async {
    await _pumpReturns(tester);

    // The card advertises that it can be opened, just like an order card.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.text('SPX4572829R9E88'));
    await tester.pumpAndSettle();

    expect(_inSheet('Return Ticket Details'), findsOneWidget);

    // Ticket information.
    expect(_inSheet('Ticket Number'), findsOneWidget);
    expect(_inSheet('ticket-123'), findsOneWidget);
    expect(_inSheet('Original Tracking Number'), findsOneWidget);
    // Shown once as the sheet subtitle and once as the field value.
    expect(_inSheet('SPX4572829R9E88'), findsNWidgets(2));
    expect(_inSheet('Platform'), findsOneWidget);
    expect(_inSheet('Shopee'), findsOneWidget);
    expect(_inSheet('Resolution'), findsOneWidget);

    // Customer.
    expect(_inSheet('Customer / Buyer Name'), findsOneWidget);
    expect(_inSheet('Maria Santos'), findsOneWidget);
    expect(_inSheet('Contact Number'), findsOneWidget);
    expect(_inSheet('09171234567'), findsOneWidget);

    // Defect details.
    expect(_inSheet('Motorcycle Plate Specifications'), findsOneWidget);
    expect(_inSheet('White plate, embossed, 4x7'), findsOneWidget);
    expect(_inSheet('Defect Category'), findsOneWidget);
    expect(_inSheet('Damaged in Transit'), findsOneWidget);
    expect(_inSheet('Defect Description / Notes'), findsOneWidget);
    expect(_inSheet('Cracked corner on the plate'), findsOneWidget);

    // Status and photo evidence section.
    expect(_inSheet('Ticket Status'), findsOneWidget);
    expect(_inSheet('PHOTO EVIDENCE'), findsOneWidget);
    expect(_inSheet('No photo evidence uploaded'), findsOneWidget);
  });

  testWidgets('older tickets keep their plate specs separate from notes',
      (tester) async {
    await _pumpReturns(
      tester,
      tickets: [
        _ticket(
          customPlateDetails: null,
          notes: 'Plate Specs: Blue plate, 4x7\nCracked edge near the bolt',
        ),
      ],
    );

    await tester.tap(find.text('SPX4572829R9E88'));
    await tester.pumpAndSettle();

    // The plate line becomes the dedicated specification value...
    expect(_inSheet('Blue plate, 4x7'), findsOneWidget);
    // ...and the notes keep only the actual description.
    expect(_inSheet('Cracked edge near the bolt'), findsOneWidget);
  });
}
