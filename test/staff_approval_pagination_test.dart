import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/staff_approval_providers.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/staff_approval_screen.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';

UserProfileModel _staff(int index) {
  return UserProfileModel(
    uid: 'staff-$index',
    email: 'staff$index@example.com',
    fullName: 'Staff $index',
    role: 'staff',
    status: 'pending',
    createdAt: DateTime(2026, 11, 10, 8),
  );
}

void main() {
  testWidgets('staff approvals show ten per page with working navigation',
      (tester) async {
    final staff =
        List<UserProfileModel>.generate(12, (index) => _staff(index + 1));

    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWithValue(true),
          pendingStaffProvider.overrideWith(
            (ref) => Stream<List<UserProfileModel>>.value(staff),
          ),
        ],
        child: const MaterialApp(
          home: StaffApprovalScreen(autoRejectExpired: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Page 1 shows the first ten registrations only.
    expect(find.text('Staff 1'), findsOneWidget);
    expect(find.text('Staff 10'), findsOneWidget);
    expect(find.text('Staff 11'), findsNothing);
    expect(
        find.text('Showing 1–10 of 12 pending registrations'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Page 2 shows the remaining two registrations.
    expect(find.text('Staff 1'), findsNothing);
    expect(find.text('Staff 11'), findsOneWidget);
    expect(find.text('Staff 12'), findsOneWidget);
    expect(
        find.text('Showing 11–12 of 12 pending registrations'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Staff 1'), findsOneWidget);
    expect(find.text('Staff 11'), findsNothing);
  });
}
