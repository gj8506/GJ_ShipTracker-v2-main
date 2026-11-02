import 'package:firebase_auth/firebase_auth.dart';

/// Details handed to the Sign Up screen when a Google sign-in turns out to have
/// no app account yet.
///
/// The Firebase session is deliberately kept alive, so the user does not have
/// to pick their Google account a second time. The Sign Up screen only asks for
/// the remaining details and creates the Firestore profile for the account that
/// is already signed in.
class SignupPrefill {
  const SignupPrefill({
    required this.email,
    required this.role,
    this.fullName = '',
    this.fromGoogleLogin = false,
  });

  /// Builds the prefill from the Google account that just signed in.
  factory SignupPrefill.fromGoogleUser(User user, {required String role}) {
    return SignupPrefill(
      email: user.email ?? '',
      fullName: (user.displayName ?? '').trim(),
      role: role,
      fromGoogleLogin: true,
    );
  }

  /// Email of the Google account, pre-filled and locked in the form.
  final String email;

  /// Google display name, used to pre-fill the full name field.
  final String fullName;

  /// `customer` or `staff`, taken from the portal tab the user was on.
  final String role;

  /// When true the Sign Up screen finishes the registration of the already
  /// authenticated Google session instead of asking for a password.
  final bool fromGoogleLogin;
}
