import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Result of translating an auth failure into something a user can act on.
class AuthErrorInfo {
  const AuthErrorInfo(this.message, {this.canResetPassword = false});

  /// Short, user-facing explanation.
  final String message;

  /// True when offering the "Reset password" shortcut makes sense.
  final bool canResetPassword;
}

/// Google Sign-In failed because the signing certificate of the installed
/// build is not registered for this Android app in Firebase.
bool _isGoogleDeveloperError(String details) {
  if (details.contains('DEVELOPER_ERROR')) return true;
  // Typical shape: "com.google.android.gms.common.api.j: 10: , null, null"
  if (details.contains('sign_in_failed') &&
      RegExp(r'(:\s*|ApiException:\s*)10\b').hasMatch(details)) {
    return true;
  }
  return RegExp(r'ApiException:\s*10\b').hasMatch(details);
}

/// Translates Firebase Auth / Google Sign-In errors into readable messages.
AuthErrorInfo describeAuthError(Object error, {bool isGoogle = false}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return const AuthErrorInfo(
          'Incorrect email or password. If you signed up with Google, tap '
          '"Continue with Google". Otherwise use "Forgot Password?" to reset it.',
          canResetPassword: true,
        );
      case 'user-not-found':
        return const AuthErrorInfo(
          'No account found with this email. Please tap "Sign Up" to create an '
          'account first.',
        );
      case 'account-exists-with-different-credential':
        return const AuthErrorInfo(
          'This email is already registered with a password. Sign in with your '
          'email and password, then try Google again.',
        );
      case 'credential-already-in-use':
        return const AuthErrorInfo(
          'This sign-in method is already linked to another account. Please '
          'contact the administrator.',
        );
      case 'operation-not-allowed':
        return const AuthErrorInfo(
          'This sign-in method is disabled for the app. Please contact the '
          'administrator.',
        );
      case 'network-request-failed':
        return const AuthErrorInfo(
          'Network error. Check your internet connection and try again.',
        );
      case 'too-many-requests':
        return const AuthErrorInfo(
          'Too many failed attempts. Please wait a few minutes and try again.',
        );
      case 'user-disabled':
        return const AuthErrorInfo(
          'This account has been disabled. Please contact the administrator.',
        );
      case 'email-already-in-use':
        return const AuthErrorInfo(
          'An account already exists with this email. Please sign in instead.',
        );
      case 'weak-password':
        return const AuthErrorInfo(
          'Please choose a stronger password (at least 6 characters).',
        );
      case 'requires-recent-login':
        return const AuthErrorInfo('Please sign in again to continue.');
      case 'invalid-email':
        return const AuthErrorInfo('Please enter a valid email address.');
      case 'internal-error':
        return const AuthErrorInfo(
          'The sign-in service is temporarily unavailable. Please try again.',
        );
      default:
        return AuthErrorInfo(
          error.message ?? 'Authentication failed. Please try again.',
        );
    }
  }

  if (error is PlatformException) {
    final details = [
      error.code,
      error.message ?? '',
      error.details?.toString() ?? '',
    ].join(' ');

    if (details.contains('sign_in_canceled') ||
        details.contains('12501') ||
        details.contains('SIGN_IN_CANCELLED')) {
      return const AuthErrorInfo('Google Sign-In was cancelled.');
    }

    if (_isGoogleDeveloperError(details)) {
      return const AuthErrorInfo(
        'Google Sign-In is not configured for this build (signing certificate '
        'mismatch). Please update the app from Google Play, or contact the '
        'administrator.',
      );
    }

    if (details.contains('network_error') || details.contains('12502')) {
      return const AuthErrorInfo(
        'Network error. Check your internet connection and try again.',
      );
    }

    if (details.contains('12500')) {
      return const AuthErrorInfo(
        'Google Sign-In could not be completed. Please try again.',
      );
    }

    return AuthErrorInfo(
      isGoogle
          ? 'Google Sign-In failed (${error.code}). Please try again.'
          : 'Sign-in failed (${error.code}). Please try again.',
    );
  }

  final text = error.toString().replaceFirst('Exception: ', '');
  return AuthErrorInfo(
      text.isEmpty ? 'Something went wrong. Please try again.' : text);
}
