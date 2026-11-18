import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/services/connectivity_service.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';
import 'package:gjandasher_shiptracker/features/dispatch/presentation/dispatch_screen.dart';
import 'package:gjandasher_shiptracker/features/shell/presentation/main_navigation_shell.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/dispatch',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainNavigationShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dispatch',
                  builder: (context, state) => const DispatchScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        isOfflineProvider.overrideWithValue(false),
        userProfileProvider.overrideWith(
          (ref) => Stream.value(
            const UserProfileModel(
              uid: 'staff-1',
              email: 'staff@example.com',
              fullName: 'Staff User',
              role: 'Admin',
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
      'dispatch form keeps its height when the shell resizes for the keyboard',
      (tester) async {
    // A phone-sized surface makes the double-inset regression obvious: with
    // the shell and the screen both shrinking, the form became a sliver.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final formScroll = find.descendant(
      of: find.byType(DispatchScreen),
      matching: find.byWidgetPredicate((widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical),
    );
    expect(formScroll, findsOneWidget);

    final heightWithoutKeyboard = tester.getSize(formScroll).height;
    expect(heightWithoutKeyboard, greaterThan(500));

    // 900 physical px at DPR 3 is a 300 logical px keyboard.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    final heightWithKeyboard = tester.getSize(formScroll).height;
    // The shell already removed the 300 px inset, so the form should only lose
    // that much. The old re-injected inset removed it a second time and left
    // roughly 140 px of usable form.
    expect(heightWithKeyboard, greaterThan(400));
    expect(heightWithoutKeyboard - heightWithKeyboard, lessThan(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('final amount field sits below the customer name field',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final customerName = fieldFor(tester, 'Customer Name *');
    final amount = fieldFor(tester, 'Final Amount (₱) *');

    expect(
      tester.getTopLeft(find.byWidget(amount)).dy,
      greaterThan(tester.getBottomLeft(find.byWidget(customerName)).dy),
    );
  });

  testWidgets('final amount stops at six whole digits', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    Finder amountField() =>
        find.byWidget(fieldFor(tester, 'Final Amount (₱) *'));

    await tester.enterText(amountField(), '1234567');
    await tester.pump();
    expect(
      fieldFor(tester, 'Final Amount (₱) *').controller!.text,
      '123456',
    );

    // Pasting a formatted, oversized amount is trimmed the same way.
    await tester.enterText(amountField(), '₱ 1,234,567.89');
    await tester.pump();
    expect(
      fieldFor(tester, 'Final Amount (₱) *').controller!.text,
      '123456.89',
    );
  });
}

TextField fieldFor(WidgetTester tester, String label) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .firstWhere((field) => field.decoration?.labelText == label);
}
