import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_list_screen.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_providers.dart';

CustomerModel _customer(int index) {
  return CustomerModel(
    id: 'customer-$index',
    name: 'Customer $index',
    contactNumber: '0917123456$index',
    address: 'Street $index, Laguna',
    type: 'regular',
    createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
  );
}

Widget _app(List<CustomerModel> customers) {
  return ProviderScope(
    overrides: [
      customersStreamProvider.overrideWith(
        (ref) => Stream<List<CustomerModel>>.value(customers),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const CustomerListScreen(),
    ),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_app(List.generate(10, (i) => _customer(i + 1))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('customer registry shows eight customers per page',
      (tester) async {
    await _pump(tester);

    expect(
      find.bySemanticsLabel('Showing 1–8 of 10 customers'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNWidgets(8));
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 9'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Showing 9–10 of 10 customers'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNWidgets(2));
    // QR preview and edit actions stay available on the next page.
    expect(find.byTooltip('View QR Code'), findsNWidgets(2));
    expect(find.byTooltip('Edit Customer'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching resets the customer list to page one', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Showing 9–10 of 10 customers'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Customer 10');
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsOneWidget);
    // The search field also contains the query, so look inside the card.
    expect(find.widgetWithText(Card, 'Customer 10'), findsOneWidget);
    expect(find.text('Customer 9'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
