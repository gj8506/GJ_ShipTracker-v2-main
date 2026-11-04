import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_list_screen.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_providers.dart';

const _longName =
    'Ana Marie Villanueva Dela Cruz Santos Reyes Bautista Jr.';

List<CustomerModel> _customers() {
  final createdAt = DateTime(2026, 1, 1);
  return [
    CustomerModel(
      id: 'c1',
      name: 'Juan Dela Cruz',
      contactNumber: '09171234567',
      address: 'Blk 4 Lot 12, Camella Homes, Dasmarinas, Cavite',
      type: 'reseller',
      createdAt: createdAt,
    ),
    CustomerModel(
      id: 'c2',
      name: _longName,
      contactNumber: '09981234567',
      address: 'Unit 18B, One Serendra, Bonifacio Global City, Taguig',
      type: 'repeat',
      createdAt: createdAt,
    ),
    CustomerModel(
      id: 'c3',
      name: 'Pedro Reyes',
      contactNumber: '',
      address: '',
      type: 'regular',
      createdAt: createdAt,
    ),
  ];
}

Widget _app({required Brightness brightness}) {
  return ProviderScope(
    overrides: [
      customersStreamProvider.overrideWith(
        (ref) => Stream<List<CustomerModel>>.value(_customers()),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const CustomerListScreen(),
    ),
  );
}

Future<void> _pumpList(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(_app(brightness: brightness));
  // Loading frame, then the streamed customer list.
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    AppColors.applyBrightness(Brightness.light);
  });

  testWidgets('every customer row has the same height', (tester) async {
    await _pumpList(tester, Brightness.light);

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(3));

    final heights = <double>{};
    for (var i = 0; i < 3; i++) {
      heights.add(tester.getSize(cards.at(i)).height);
    }

    expect(heights, hasLength(1),
        reason: 'Rows with and without an address must align: $heights');
    expect(tester.takeException(), isNull);
  });

  testWidgets('long names stay on one line instead of pushing the badge',
      (tester) async {
    await _pumpList(tester, Brightness.light);

    final name = tester.widget<Text>(find.text(_longName));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing contact and address still render a full row',
      (tester) async {
    await _pumpList(tester, Brightness.light);

    expect(find.text('No contact provided'), findsOneWidget);
    expect(find.text('No address on file'), findsOneWidget);
  });

  testWidgets('rows render without overflow in dark mode', (tester) async {
    await _pumpList(tester, Brightness.dark);

    expect(find.byType(Card), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no manual add-customer actions are offered', (tester) async {
    await _pumpList(tester, Brightness.light);

    // Customers self-register, so the registry must not expose a manual add
    // button or floating action button.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add Customer'), findsNothing);
    expect(find.text('Add First Customer'), findsNothing);
  });

  testWidgets('empty registry explains that sign-ups populate the list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppColors.applyBrightness(Brightness.light);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith(
            (ref) => Stream<List<CustomerModel>>.value(
              const <CustomerModel>[],
            ),
          ),
        ],
        child: const MaterialApp(home: CustomerListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No Customers Yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add First Customer'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
