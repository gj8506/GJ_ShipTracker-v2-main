import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/auth/data/auth_repository.dart';
import 'package:gjandasher_shiptracker/features/auth/data/staff_registration_limiter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeGoogleSignIn implements GoogleSignIn {
  _FakeGoogleSignIn({this.throwOnSignOut = false});

  final bool throwOnSignOut;
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) {
      throw Exception('Google Sign-In is unavailable');
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

AuthRepository _repository(
  _FakeFirebaseAuth auth,
  _FakeGoogleSignIn google,
) {
  final firestore = _FakeFirestore();
  return AuthRepository(
    auth: auth,
    firestore: firestore,
    googleSignIn: google,
    staffRegistrationLimiter: StaffRegistrationLimiter(firestore: firestore),
  );
}

void main() {
  test('signOut clears both the Firebase and Google sessions', () async {
    final auth = _FakeFirebaseAuth();
    final google = _FakeGoogleSignIn();

    await _repository(auth, google).signOut();

    expect(auth.signOutCalls, 1);
    expect(google.signOutCalls, 1);
  });

  test('a failed Google sign-out never leaves the Firebase session active',
      () async {
    final auth = _FakeFirebaseAuth();
    final google = _FakeGoogleSignIn(throwOnSignOut: true);

    // Logout must stay smooth: the Google plugin is optional, but Firebase
    // Auth is the session the router and every portal watch.
    await expectLater(_repository(auth, google).signOut(), completes);

    expect(auth.signOutCalls, 1);
    expect(google.signOutCalls, 1);
  });
}
