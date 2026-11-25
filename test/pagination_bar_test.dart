import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';
import 'package:gjandasher_shiptracker/core/widgets/pagination_bar.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.itemCount, this.theme});

  final int itemCount;
  final ThemeData? theme;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = PaginationBar.pageCountFor(widget.itemCount, 10);
    return MaterialApp(
      theme: widget.theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: PaginationBar(
            page: _page,
            pageCount: pageCount,
            itemCount: widget.itemCount,
            pageSize: 10,
            itemLabel: 'parcels',
            onPageChanged: (page) => setState(() => _page = page),
          ),
        ),
      ),
    );
  }
}

InkWell _arrow(WidgetTester tester, String label) {
  return tester.widget<InkWell>(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
}

Color _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style!.color!;
}

double _contrast(Color foreground, Color background) {
  final fg = foreground.computeLuminance();
  final bg = background.computeLuminance();
  final lighter = fg > bg ? fg : bg;
  final darker = fg > bg ? bg : fg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() => AppColors.applyBrightness(Brightness.light));
  tearDown(() => AppColors.applyBrightness(Brightness.light));

  testWidgets('renders a compact Back 1 2 3 Next row', (tester) async {
    await tester.pumpWidget(const _Harness(itemCount: 24));

    // The count remains available to screen readers but the visible control
    // is just one compact line of numbers and text arrows.
    expect(
      find.bySemanticsLabel('Showing 1–10 of 24 parcels'),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    expect(_arrow(tester, 'Back').onTap, isNull,
        reason: 'Back must be disabled on the first page');
    expect(_arrow(tester, 'Next').onTap, isNotNull);
  });

  testWidgets('Back and Next move through the pages', (tester) async {
    await tester.pumpWidget(const _Harness(itemCount: 24));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Showing 11–20 of 24 parcels'),
      findsOneWidget,
    );
    expect(_arrow(tester, 'Back').onTap, isNotNull);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Showing 21–24 of 24 parcels'),
      findsOneWidget,
    );
    expect(_arrow(tester, 'Next').onTap, isNull);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Showing 11–20 of 24 parcels'),
      findsOneWidget,
    );
  });

  testWidgets('stays on one line on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness(itemCount: 80));
    await tester.pumpAndSettle();

    // Eight pages produce a five-number window plus a trailing gap marker.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('colors follow light and dark themes', (tester) async {
    final light = AppTheme.lightTheme;
    await tester.pumpWidget(_Harness(itemCount: 24, theme: light));
    await tester.pumpAndSettle();

    expect(_textColor(tester, 'Next'), light.colorScheme.primary);
    expect(_textColor(tester, '1'), light.colorScheme.onPrimary);
    expect(
      _contrast(
        light.colorScheme.onPrimary,
        light.colorScheme.primary,
      ),
      greaterThanOrEqualTo(4.5),
      reason: 'the selected page must stay readable in light mode',
    );

    final dark = AppTheme.darkTheme;
    await tester.pumpWidget(_Harness(itemCount: 24, theme: dark));
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget);
    expect(_textColor(tester, 'Next'), dark.colorScheme.primary);
    expect(_textColor(tester, '1'), dark.colorScheme.onPrimary);
    expect(
      _contrast(
        dark.colorScheme.onPrimary,
        dark.colorScheme.primary,
      ),
      greaterThanOrEqualTo(4.5),
      reason: 'the selected page must stay readable in dark mode',
    );
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
