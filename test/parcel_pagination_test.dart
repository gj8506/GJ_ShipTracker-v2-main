import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';
import 'package:gjandasher_shiptracker/features/parcels/domain/parcel_model.dart';
import 'package:gjandasher_shiptracker/features/parcels/presentation/parcel_providers.dart';
import 'package:gjandasher_shiptracker/features/parcels/presentation/parcels_dashboard_screen.dart';

ParcelModel _parcel(int index) {
  return ParcelModel(
    id: 'parcel-$index',
    trackingNumber: 'TRACK${index.toString().padLeft(10, '0')}',
    platform: AppConstants.platformShopee,
    customerName: 'Customer $index',
    amount: 1000.0 + index,
    courier: AppConstants.courierSPX,
    status: AppConstants.statusDispatched,
    createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
  );
}

Widget _app(List<ParcelModel> parcels) {
  return ProviderScope(
    overrides: [
      parcelsStreamProvider.overrideWith(
        (ref) => Stream<List<ParcelModel>>.value(parcels),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ParcelsDashboardScreen(),
    ),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_app(List.generate(12, (i) => _parcel(i + 1))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('parcel dashboard shows ten parcels per page', (tester) async {
    await _pump(tester);

    expect(find.bySemanticsLabel('Showing 1–10 of 12 parcels'), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 10'), findsOneWidget);
    expect(find.text('Customer 11'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Showing 11–12 of 12 parcels'), findsOneWidget);
    expect(find.text('Customer 1'), findsNothing);
    expect(find.text('Customer 11'), findsOneWidget);
    expect(find.text('Customer 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page controls sit below all ten cards on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(List.generate(12, (i) => _parcel(i + 1))));
    await tester.pumpAndSettle();

    // The tenth card and the controls are only reachable by scrolling.
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    final listScroll = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    );
    await tester.scrollUntilVisible(
      find.text('Customer 10'),
      300,
      scrollable: listScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('Customer 10'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Back'),
      300,
      scrollable: listScroll,
    );
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('69 parcels keep ten readable cards and a compact footer',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(List.generate(69, (i) => _parcel(i + 1))));
    await tester.pumpAndSettle();

    // The old stacked "Page 1 … Page 7" footer is gone.
    expect(find.text('Page 1'), findsNothing);
    expect(find.text('Previous'), findsNothing);

    final listScroll = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    );
    await tester.scrollUntilVisible(
      find.text('Back'),
      300,
      scrollable: listScroll,
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Showing 1–10 of 69 parcels'),
      findsOneWidget,
    );
    expect(find.text('Customer 10'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching resets the parcel list to page one', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsLabel('Showing 11–12 of 12 parcels'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Customer 11');
    await tester.pumpAndSettle();

    // A single filtered result hides the pagination footer but still resets
    // the page index, so the matching parcel is visible.
    expect(find.byType(Card), findsOneWidget);
    expect(find.widgetWithText(Card, 'Customer 11'), findsOneWidget);
    expect(find.text('Customer 12'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
