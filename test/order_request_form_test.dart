import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';
import 'package:gjandasher_shiptracker/features/customer/presentation/order_request_form_screen.dart';

Widget _buildForm() {
  return ProviderScope(
    overrides: [
      // Keep the screen offline: no Firebase streams are needed to render it.
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      userProfileProvider
          .overrideWith((ref) => Stream<UserProfileModel?>.value(null)),
    ],
    child: const MaterialApp(home: OrderRequestFormScreen()),
  );
}

/// The form's dropdowns in source order: style, region, make, delivery area.
DropdownButton<String> _dropdown(WidgetTester tester, int index) {
  return tester.widget<DropdownButton<String>>(
    find.byType(DropdownButton<String>).at(index),
  );
}

void main() {
  testWidgets('order form uses dropdowns for the conversion fields',
      (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();

    expect(find.text('Plate Shape / Style *'), findsOneWidget);
    expect(find.text('Region *'), findsOneWidget);
    expect(find.text('Motorcycle Make *'), findsOneWidget);
    expect(find.text('Delivery Area *'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNWidgets(4));

    // The new plate choices replace the old separate options.
    expect(_dropdown(tester, 0).items!.map((i) => i.value), [
      'Standard (Irregular Hexagon)',
      'Large',
    ]);
    expect(find.text('Irregular Hexagon'), findsNothing);

    // A listed area only asks for the street/barangay line.
    expect(find.text('House No., Street, Barangay *'), findsOneWidget);
    expect(find.text('Complete Shipping Address *'), findsNothing);
  });

  testWidgets('choosing Other reveals a full free-text address field',
      (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();

    _dropdown(tester, 3).onChanged!('Other (type full address)');
    await tester.pumpAndSettle();

    expect(find.text('Complete Shipping Address *'), findsOneWidget);
    expect(find.text('House No., Street, Barangay *'), findsNothing);
  });

  testWidgets('choosing a listed area keeps the short address field',
      (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();

    _dropdown(tester, 3).onChanged!('Other (type full address)');
    await tester.pumpAndSettle();
    _dropdown(tester, 3).onChanged!('Nagcarlan, Laguna');
    await tester.pumpAndSettle();

    expect(find.text('House No., Street, Barangay *'), findsOneWidget);
    expect(find.text('Complete Shipping Address *'), findsNothing);
  });

  testWidgets('the Large style keeps the plate preview in sync',
      (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();

    // Standard uses the irregular hexagon clip.
    expect(find.byType(ClipPath), findsOneWidget);

    _dropdown(tester, 0).onChanged!('Large');
    await tester.pumpAndSettle();

    // Large is the rectangular plate.
    expect(find.byType(ClipPath), findsNothing);
  });
}
