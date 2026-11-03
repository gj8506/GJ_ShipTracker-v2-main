import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/customer/data/models/order_request_model.dart';
import 'package:gjandasher_shiptracker/features/parcels/domain/parcel_model.dart';
import 'package:gjandasher_shiptracker/features/parcels/presentation/parcel_providers.dart';
import 'package:gjandasher_shiptracker/features/search_summary/presentation/search_summary_providers.dart';
import 'package:gjandasher_shiptracker/features/search_summary/presentation/search_summary_screen.dart';

ParcelModel _parcel({
  required String tracking,
  required String customer,
  double amount = 100,
  String status = 'Delivered',
  required DateTime createdAt,
}) {
  return ParcelModel(
    id: 'parcel-$tracking',
    trackingNumber: tracking,
    platform: 'Shopee',
    customerName: customer,
    contactNumber: '09171234567',
    address: 'Quezon City',
    items: 'Standard (Irregular Hexagon)',
    amount: amount,
    courier: 'SPX Express',
    status: status,
    createdAt: createdAt,
  );
}

OrderRequestModel _order({
  required DateTime createdAt,
  String plate = 'ABC 1234',
}) {
  return OrderRequestModel(
    id: 'order-1',
    customerId: '',
    customerName: 'Pedro Reyes',
    customerPhone: '09170000000',
    plateText: plate,
    plateStyle: 'Standard (Irregular Hexagon)',
    vehicleType: 'Sedan / SUV',
    deliveryAddress: 'Cebu City',
    price: 1200,
    status: 'pending',
    trackingNumber: 'ORD-TRK-1',
    createdAt: createdAt,
  );
}

Widget _app({
  required List<ParcelModel> parcels,
  required List<OrderRequestModel> orders,
}) {
  return ProviderScope(
    overrides: [
      parcelsStreamProvider.overrideWith(
        (ref) => Stream<List<ParcelModel>>.value(parcels),
      ),
      allOrderRequestsStreamProvider.overrideWith(
        (ref) => Stream<List<OrderRequestModel>>.value(orders),
      ),
    ],
    child: const MaterialApp(home: SearchSummaryScreen()),
  );
}

void _sizeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final now = DateTime.now();
  final oldDate = now.subtract(const Duration(days: 30));

  List<ParcelModel> parcels() => [
        _parcel(
          tracking: 'TRK-ALPHA',
          customer: 'Maria Santos',
          amount: 100,
          createdAt: now,
        ),
        _parcel(
          tracking: 'TRK-OLD',
          customer: 'Juan Dela Cruz',
          amount: 50,
          status: 'Returned',
          createdAt: oldDate,
        ),
      ];

  List<OrderRequestModel> orders() => [_order(createdAt: now)];

  Future<void> pump(WidgetTester tester) async {
    _sizeSurface(tester);
    await tester.pumpWidget(_app(parcels: parcels(), orders: orders()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows totals for parcels and orders', (tester) async {
    await pump(tester);

    expect(find.text('TRK-ALPHA'), findsOneWidget);
    expect(find.text('TRK-OLD'), findsOneWidget);
    expect(find.text('ABC 1234'), findsOneWidget);
    expect(find.text('1 delivered • 1 returned'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    // 100 + 50 in parcels plus the 1200 order.
    expect(find.text('₱1,350.00'), findsOneWidget);
  });

  testWidgets('searches across parcel and order fields', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Juan');
    await tester.pumpAndSettle();

    expect(find.text('TRK-OLD'), findsOneWidget);
    expect(find.text('TRK-ALPHA'), findsNothing);
    expect(find.text('ABC 1234'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.pumpAndSettle();

    expect(find.text('ABC 1234'), findsOneWidget);
    expect(find.text('TRK-OLD'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.pumpAndSettle();

    expect(find.text('No results match your search'), findsOneWidget);
  });

  testWidgets('Today chip hides older history', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('TRK-ALPHA'), findsOneWidget);
    expect(find.text('TRK-OLD'), findsNothing);
    expect(find.text('1 delivered • 0 returned'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();

    expect(find.text('TRK-OLD'), findsOneWidget);
  });

  testWidgets('tapping an order opens its detail sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.text('ABC 1234'));
    await tester.pumpAndSettle();

    expect(find.text('Order ABC 1234'), findsOneWidget);
    expect(find.text('Pedro Reyes'), findsWidgets);
    expect(find.text('Estimated price'), findsOneWidget);
    expect(find.text('Cebu City'), findsOneWidget);
  });
}
