import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';
import 'package:gjandasher_shiptracker/features/support_chat/domain/support_chat_model.dart';
import 'package:gjandasher_shiptracker/features/support_chat/presentation/admin_inbox_screen.dart';
import 'package:gjandasher_shiptracker/features/support_chat/presentation/support_chat_providers.dart';

UserProfileModel _profile(String role) => UserProfileModel(
      uid: 'u1',
      email: 'tester@example.com',
      fullName: 'Test User',
      role: role,
    );

Widget _app(String role) {
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith(
        (ref) => Stream<UserProfileModel?>.value(_profile(role)),
      ),
      // The staff guard returns before this stream is read; the admin case
      // needs it so the inbox never reaches for a real Firestore instance.
      adminThreadsProvider.overrideWith(
        (ref) => Stream<List<SupportChatThread>>.value(const []),
      ),
    ],
    child: const MaterialApp(home: AdminInboxScreen()),
  );
}

void main() {
  testWidgets('staff accounts cannot open the customer support inbox',
      (tester) async {
    await tester.pumpWidget(_app('staff'));
    await tester.pumpAndSettle();

    expect(find.text('Restricted to the owner/admin account'), findsOneWidget);
    expect(find.text('Open Tickets'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the owner/admin account sees the support inbox', (tester) async {
    await tester.pumpWidget(_app('admin'));
    await tester.pumpAndSettle();

    expect(find.text('Restricted to the owner/admin account'), findsNothing);
    expect(find.text('Open Tickets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
