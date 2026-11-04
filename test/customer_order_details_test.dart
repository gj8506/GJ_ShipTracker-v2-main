import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/customer/presentation/customer_my_orders_screen.dart';
import 'package:gjandasher_shiptracker/features/customer/presentation/customer_portal_providers.dart';

void main() {
  testWidgets('customer order card opens the full order details',
      (tester) async {
    final order = <String, dynamic>{
      'id': 'order-123',
      'userId': 'customer-1',
      'customerName': 'Maria Santos',
      'contactNumber': '09171234567',
      'deliveryAddress': '12 Mabini Street, Quezon City',
      'plateNumber': 'ABC 123',
      'plateStyle': 'custom',
      'region': 'NCR',
      'brandMake': 'Honda Click 125i',
      'plateSpecs': 'CUSTOM | Reg: NCR | Make: Honda Click 125i',
      'price': 1200.0,
      'estimatedPrice': 1200.0,
      'finalAmount': 1750.50,
      'trackingNumber': 'DHL123456',
      'specialNotes': 'Use a white reflective background.',
      'status': 'DISPATCHED',
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 4)),
    };

    final container = ProviderContainer(
      overrides: [
        customerOrdersStreamProvider
            .overrideWith((ref) => Stream.value([order])),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomerMyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The card shows the final price and a clear affordance to open it.
    expect(find.text('ABC 123'), findsOneWidget);
    expect(find.textContaining('1,750.50'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.text('ABC 123'));
    await tester.pumpAndSettle();

    // The sheet exposes the full specifications, price, tracking and notes.
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('FINAL PRICE'), findsOneWidget);
    expect(find.textContaining('1,750.50'), findsWidgets);
    expect(
      find.textContaining('Original estimate'),
      findsOneWidget,
      reason: 'the customer should still see what they were first quoted',
    );
    expect(
        find.text('CUSTOM | Reg: NCR | Make: Honda Click 125i'), findsWidgets);
    expect(find.text('Honda Click 125i'), findsWidgets);
    expect(find.text('DHL123456'), findsOneWidget);
    expect(find.text('Use a white reflective background.'), findsOneWidget);
    expect(find.text('DISPATCHED'), findsWidgets);
  });
}
