import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gjandasher_shiptracker/app.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';

void main() {
  testWidgets('ShipTrackerApp loads smoke test', (WidgetTester tester) async {
    // 1. Create a dummy navigator key for the test environment
    final testNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        // The test environment has no Firebase app, so provide a signed-out
        // auth stream instead of touching FirebaseAuth.
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: ShipTrackerApp(navigatorKey: testNavigatorKey),
      ),
    );

    // Let the splash screen's 2-second timer finish and route to login.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
