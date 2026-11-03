import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/signup_prefill.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/signup_screen.dart';

void main() {
  testWidgets(
    'a Google sign-in with no account opens the form pre-filled',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(
              prefill: SignupPrefill(
                email: 'tester@example.com',
                fullName: 'Test Tester',
                role: 'customer',
                fromGoogleLogin: true,
              ),
            ),
          ),
        ),
      );

      // Google-specific copy replaces the normal sign-up heading.
      expect(find.text('Finish Your Account'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);

      // Details carried over from the Google account.
      expect(find.text('tester@example.com'), findsWidgets);
      expect(find.text('Test Tester'), findsOneWidget);

      // The Google account already authenticated, so a password is optional:
      // the fields stay hidden until the user asks for one, and the Google
      // button is not offered a second time.
      expect(find.text('Finish Account Setup'), findsOneWidget);
      expect(find.text('Add a password (optional)'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Confirm Password'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);

      // Opting in reveals the password fields for the new account.
      await tester.tap(find.text('Add a password (optional)'));
      await tester.pumpAndSettle();
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    },
  );

  testWidgets('a normal sign-up keeps the password form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Finish Your Account'), findsNothing);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('SignupPrefill defaults to a non-Google prefill', () {
    const prefill = SignupPrefill(email: 'a@b.com', role: 'staff');
    expect(prefill.fromGoogleLogin, isFalse);
    expect(prefill.fullName, isEmpty);
  });
}
