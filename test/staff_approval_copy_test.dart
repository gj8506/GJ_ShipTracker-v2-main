import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/staff_approval_providers.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/staff_approval_screen.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';

const _pendingStaff = UserProfileModel(
  uid: 'staff-1',
  email: 'ana.cruz@example.com',
  fullName: 'Ana Cruz',
  role: AppConstants.roleStaff,
  status: AppConstants.accountStatusPending,
);

Widget _screenFor(Brightness brightness) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(true),
      pendingStaffProvider.overrideWith(
        (ref) => Stream.value(const [_pendingStaff]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.themeFor(brightness),
      home: const StaffApprovalScreen(autoRejectExpired: false),
    ),
  );
}

double _contrast(Color foreground, Color background) {
  final fg = foreground.computeLuminance();
  final bg = background.computeLuminance();
  final lighter = fg > bg ? fg : bg;
  final darker = fg > bg ? bg : fg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.light));

  testWidgets('Staff Approvals shows user-facing copy, not build variables',
      (tester) async {
    await tester.pumpWidget(_screenFor(Brightness.light));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Ana Cruz'), findsWidgets);

    // No developer-facing instructions may reach the admin.
    expect(find.textContaining('EMAIL_WORKER_URL'), findsNothing);
    expect(find.textContaining('EMAIL_API_KEY'), findsNothing);
    expect(find.textContaining('Rebuild with'), findsNothing);
    expect(
        find.textContaining('email worker', findRichText: false), findsNothing);

    expect(
      find.textContaining('Automatic approval emails are unavailable'),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('Staff Approvals banner stays readable in $brightness mode',
        (tester) async {
      await tester.pumpWidget(_screenFor(brightness));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        _contrast(AppColors.warningDeep, AppColors.warningSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'the email notice must stay readable',
      );
      expect(
        _contrast(AppColors.textSecondary, AppColors.tealContainer),
        greaterThanOrEqualTo(4.5),
        reason: 'the queue notice must stay readable',
      );
    });
  }
}
