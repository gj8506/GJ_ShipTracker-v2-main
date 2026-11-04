import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/app.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';
import 'package:gjandasher_shiptracker/core/services/dpa_service.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';

void main() {
  testWidgets('ShipTrackerApp loads smoke test', (WidgetTester tester) async {
    // 1. Create a dummy messenger key for the test environment
    final testMessengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      ProviderScope(
        // 2. Avoid touching Firebase in widget tests: simulate a signed-out user.
        //    Also treat the Data Privacy agreement as accepted so the smoke
        //    test reaches the login screen instead of stopping at the DPA gate.
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          dpaAcceptedStatusProvider.overrideWith((ref) async => true),
        ],
        // 3. Pass the test key to the app
        child: ShipTrackerApp(scaffoldMessengerKey: testMessengerKey),
      ),
    );

    // Let the auth stream emit and the splash screen navigate to login.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
