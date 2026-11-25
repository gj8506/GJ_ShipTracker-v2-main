import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/widgets/pagination_bar.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.itemCount});

  final int itemCount;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = PaginationBar.pageCountFor(widget.itemCount, 10);
    return MaterialApp(
      home: Scaffold(
        body: PaginationBar(
          page: _page,
          pageCount: pageCount,
          itemCount: widget.itemCount,
          pageSize: 10,
          itemLabel: 'parcels',
          onPageChanged: (page) => setState(() => _page = page),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('renders numbered page pills inside a Wrap', (tester) async {
    await tester.pumpWidget(const _Harness(itemCount: 24));

    expect(find.text('Showing 1–10 of 24 parcels'), findsOneWidget);
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    final previous = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Previous'),
    );
    expect(previous.onPressed, isNull,
        reason: 'Previous must be disabled on the first page');
  });

  testWidgets('Previous and Next move through the pages', (tester) async {
    await tester.pumpWidget(const _Harness(itemCount: 24));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 11–20 of 24 parcels'), findsOneWidget);
    final next = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 21–24 of 24 parcels'), findsOneWidget);

    final lastNext = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Next'),
    );
    expect(lastNext.onPressed, isNull);
  });

  testWidgets('page pills wrap instead of overflowing a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness(itemCount: 80));
    await tester.pumpAndSettle();

    expect(find.byType(Wrap), findsOneWidget);
    // Eight pages produce a five-pill window plus a trailing gap marker; the
    // compact numeric pills fit on a narrow phone without stacking.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('page helpers clamp and slice without touching the source list', () {
    final items = List<int>.generate(12, (index) => index);

    expect(PaginationBar.pageCountFor(12, 10), 2);
    expect(PaginationBar.pageCountFor(0, 10), 1);
    expect(PaginationBar.clampPage(5, 12, 10), 1);
    expect(PaginationBar.clampPage(-2, 12, 10), 0);

    expect(PaginationBar.pageSlice(items, 0, 10), hasLength(10));
    expect(PaginationBar.pageSlice(items, 1, 10), <int>[10, 11]);
    expect(items, hasLength(12), reason: 'the source list must be untouched');
  });
}
