import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/email_service.dart';
import '../domain/user_profile_model.dart';
import '../../qr_customers/domain/customer_model.dart'; // Added import for customer synchronization
import 'staff_registration_limiter.dart';

/// The Web OAuth client of Firebase project `shiptracker-v2`.
///
/// Passing it as `serverClientId` makes Google Sign-In return an `idToken`,
/// which Firebase needs to turn a Google account into a Firebase credential.
/// Without it the `idToken` is often null and the Firebase sign-in fails even
/// when the Android OAuth client is configured correctly.
const String kGoogleServerClientId =
    '1051323344116-ffvoqqr66nsandtoe3pf0do35rvrc8nj.apps.googleusercontent.com';

/// Which sender was used for a password-reset email.
enum PasswordResetDelivery {
  /// Sent through the Cloudflare worker from the verified custom domain.
  branded,

  /// Sent by Firebase Auth from `<project>.firebaseapp.com`, which mailbox
  /// providers commonly filter into Spam.
  firebaseFallback,
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final StaffRegistrationLimiter _staffRegistrationLimiter;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    StaffRegistrationLimiter? staffRegistrationLimiter,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _staffRegistrationLimiter =
            staffRegistrationLimiter ?? StaffRegistrationLimiter(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: kGoogleServerClientId,
              scopes: const <String>['email', 'profile'],
            );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ==========================================
  // SIGN IN WITH GOOGLE
  // ==========================================
  /// Authenticates with Google only. It never creates a Firestore profile:
  /// accounts must be created through the Sign Up screen first.
  ///
  /// Throws a `FirebaseAuthException` or a `PlatformException` which the
  /// caller can translate into a readable message.
  Future<UserCredential?> signInWithGoogle() async {
    // FORCE ACCOUNT PICKER: Clear the cached Google session first
    await _googleSignIn.signOut();

    // 1. Trigger the Google Authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    // 2. Obtain the auth details
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // The idToken is what Firebase actually validates. If it is missing the
    // credential below would silently fail, so surface a clear error instead.
    if (googleAuth.idToken == null) {
      throw Exception(
        'Google did not return an ID token. Please make sure the app was '
        'installed from Google Play and try again.',
      );
    }

    // 3. Create a credential for Firebase
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'An account with ${googleUser.email} already exists using a '
          'password. Sign in with your email and password instead.',
        );
      }
      rethrow;
    }
  }

  /// Best-effort lookup of the sign-in providers registered for [email].
  ///
  /// Returns an empty list when Firebase hides the result (email enumeration
  /// protection) or when the request fails, so callers must treat the result
  /// as a hint only.
  ///
  /// `fetchSignInMethodsForEmail` is deprecated upstream (email enumeration
  /// protection), but it is the only client-side way to tell a Google-only
  /// account apart from a password account.
  // ignore: deprecated_member_use
  Future<List<String>> signInMethodsForEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) return const <String>[];
    try {
      // ignore: deprecated_member_use
      return await _auth.fetchSignInMethodsForEmail(trimmed);
    } catch (_) {
      return const <String>[];
    }
  }

  // ==========================================
  // SIGN UP WITH GOOGLE
  // ==========================================
  /// Authenticates with Google and creates the Firestore profile for a new
  /// account. Existing accounts are rejected so users sign in instead.
  Future<UserCredential?> signUpWithGoogle({
    required String role,
    String? fullName,
    String? phoneNumber,
  }) async {
    final userCredential = await signInWithGoogle();
    final user = userCredential?.user;
    if (user == null) return null;

    final userDoc = await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      await signOut();
      throw Exception(
        'An account with this Google account already exists. Please sign in instead.',
      );
    }

    try {
      await _createUserProfile(
        user,
        role,
        fullName: fullName ?? user.displayName,
        phoneNumber: phoneNumber,
      );
    } on StaffApplicationLimitException {
      // Do not leave a Google session signed in without an app profile.
      await signOut();
      rethrow;
    }

    return userCredential;
  }

  /// Creates the Firestore profile for the Google account that is already
  /// signed in to Firebase.
  ///
  /// The login screen routes here when a Google sign-in succeeds but no app
  /// account exists yet, so the user finishes registration without having to
  /// choose their Google account a second time.
  ///
  /// When [password] is given, it is attached to the same Firebase account so
  /// the user can also sign in with their email address and password later.
  ///
  /// Throws when there is no Google session, or when the signed-in account uses
  /// a different sign-in method.
  Future<UserProfileModel?> completeGoogleSignUp({
    required String role,
    String? fullName,
    String? phoneNumber,
    String? password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        'Your Google session has expired. Please sign in with Google again.',
      );
    }

    final isGoogleAccount =
        user.providerData.any((info) => info.providerId == 'google.com');
    if (!isGoogleAccount) {
      throw Exception(
        'This account was not created with Google. Please use the sign-up '
        'form instead.',
      );
    }

    // Set the optional app password first, so a rejected password leaves no
    // half-finished registration behind.
    final appPassword = (password ?? '').trim();
    if (appPassword.isNotEmpty) {
      await _setAppPassword(user, appPassword);
    }

    // Already registered (for example a retried request): keep the profile.
    final existing = await getUserProfile(user.uid);
    if (existing != null) return existing;

    final trimmedName = (fullName ?? '').trim();

    try {
      await _createUserProfile(
        user,
        role,
        fullName: trimmedName.isEmpty ? null : trimmedName,
        phoneNumber: phoneNumber,
      );
    } on StaffApplicationLimitException {
      // Keep the user out of the app when the staff cap is full; they can
      // retry tomorrow without a half-created profile.
      await signOut();
      rethrow;
    }

    return getUserProfile(user.uid);
  }

  /// Gives the signed-in account an email/password sign-in option.
  ///
  /// Firebase attaches the password to the existing (Google) account instead of
  /// creating a second one, so both sign-in methods reach the same profile.
  Future<void> _setAppPassword(User user, String password) async {
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    try {
      await user.updatePassword(password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Your Google session is too old to save a password. Sign in with '
          'Google again and retry.',
        );
      }
      rethrow;
    }
  }

  /// Creates the Firestore profile and, for customers, the linked registry row.
  Future<void> _createUserProfile(
    User user,
    String role, {
    String? fullName,
    String? phoneNumber,
  }) async {
    final displayName = fullName ?? user.displayName ?? '';
    final assignedRole = role.trim().isEmpty
        ? AppConstants.roleCustomer
        : role.trim().toLowerCase();
    final isStaffRole = assignedRole == AppConstants.roleStaff;

    // Authoritative daily cap: claim a slot before the staff profile exists.
    // Throws StaffApplicationLimitException when today's applications are full.
    if (isStaffRole) {
      await _staffRegistrationLimiter.reserveSlot();
    }

    final profile = UserProfileModel(
      uid: user.uid,
      email: user.email ?? '',
      fullName: displayName,
      role: assignedRole,
      status: isStaffRole
          ? AppConstants.accountStatusPending
          : AppConstants.accountStatusActive,
      phoneNumber:
          (phoneNumber ?? '').trim().isEmpty ? null : phoneNumber!.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(user.uid)
        .set(profile.toMap());

    // Sync to Customer Registry & QR system if role is customer
    if (assignedRole == AppConstants.roleCustomer) {
      await _syncCustomerRegistry(user.uid, profile);
    }
  }

  /// Creates the Customer Registry row for a newly registered customer.
  ///
  /// The document id is the Firebase uid, which makes the sync idempotent and
  /// gives the customer a stable QR payload (`GJAS1:<uid>`). The registry
  /// streams the `customers` collection, so the row — and its QR — appears in
  /// the Admin/Dispatch Customer Registry as soon as this write lands.
  ///
  /// If a row already exists it is left untouched: an admin may have already
  /// edited the address or category, and a retried sign-up must not reset it.
  Future<void> _syncCustomerRegistry(
    String uid,
    UserProfileModel profile,
  ) async {
    final docRef =
        _firestore.collection(AppConstants.collectionCustomers).doc(uid);

    final existing = await docRef.get();
    if (existing.exists) return;

    final customer = CustomerModel.forAccount(
      uid: uid,
      name: profile.fullName,
      contactNumber: profile.phoneNumber ?? '',
    );

    await docRef.set(customer.toFirestore());
  }

  /// Returns the Firestore profile for [uid], or null when no account exists.
  Future<UserProfileModel?> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfileModel.fromMap(doc.data()!);
  }

  // Sign in using named parameters
  //
  // The password is sent exactly as typed first. Older builds trimmed the
  // password before creating the account, so if that attempt is rejected we
  // retry with the trimmed value. This keeps legacy accounts (and passwords
  // typed with a stray leading/trailing space) working.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _signInWithPassword(email, password);
  }

  // Positional alias for signInWithEmailAndPassword
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return _signInWithPassword(email, password);
  }

  Future<UserCredential> _signInWithPassword(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim();
    try {
      return await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      final trimmedPassword = password.trim();
      final isCredentialError =
          e.code == 'invalid-credential' || e.code == 'wrong-password';
      if (isCredentialError && trimmedPassword != password) {
        return _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: trimmedPassword,
        );
      }
      rethrow;
    }
  }

  // Sign up using named parameters (defaults to customer if not specified)
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? username,
    String? fullName,
    String? role,
    String? phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user != null) {
      final displayName = fullName ?? username ?? '';

      try {
        await _createUserProfile(
          user,
          role ?? '',
          fullName: displayName.isEmpty ? null : displayName,
          phoneNumber: phoneNumber,
        );
      } on StaffApplicationLimitException {
        // Remove the just-created Auth user so the address stays free for a
        // future attempt once today's staff slots open again.
        await _deleteAuthUserQuietly(user);
        rethrow;
      }

      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
    }

    return credential;
  }

  /// Best-effort cleanup after an aborted registration.
  Future<void> _deleteAuthUserQuietly(User user) async {
    try {
      await user.delete();
    } catch (_) {
      // Deleting can require a recent login; at minimum drop the session.
      await signOut();
    }
  }

  // Password reset. When the branded email worker is configured we send a
  // custom reset link from the verified domain; otherwise we fall back to
  // Firebase Auth's built-in reset email so the flow never breaks.
  //
  // The fallback is sent from `<project>.firebaseapp.com`, which Gmail and
  // Outlook routinely filter into Spam. Callers use the returned value to tell
  // the user to check their Spam folder in that case.
  Future<PasswordResetDelivery> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    final emailService = EmailService();

    if (emailService.isConfigured) {
      try {
        await emailService.sendPasswordReset(email: trimmed);
        return PasswordResetDelivery.branded;
      } catch (_) {
        // Fall through to Firebase Auth's reset email.
      }
    }

    await _auth.sendPasswordResetEmail(email: trimmed);
    return PasswordResetDelivery.firebaseFallback;
  }

  // Quick helper to ensure or switch role for testing
  Future<void> setUserRole(String uid, String newRole) async {
    await _firestore.collection(AppConstants.collectionUsers).doc(uid).set(
        {'role': newRole, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // Update Profile
  Future<void> updateProfile({
    String? uid,
    String? fullName,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    UserProfileModel? profile,
  }) async {
    final targetUid = uid ?? profile?.uid ?? _auth.currentUser?.uid;
    if (targetUid == null) return;

    final name = fullName ?? displayName ?? profile?.fullName;

    final Map<String, dynamic> updateData = profile != null
        ? profile.toMap()
        : {
            if (name != null) 'fullName': name,
            if (name != null) 'displayName': name,
            if (phoneNumber != null) 'phoneNumber': phoneNumber,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          };

    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(targetUid)
        .set(updateData, SetOptions(merge: true));

    // Keep the Admin/Dispatch Customer Registry in step with customer profile
    // edits (the registry streams the `customers` collection).
    await _mirrorCustomerRegistryRow(
      targetUid,
      name: name,
      phoneNumber: phoneNumber,
    );

    if (name != null && name.isNotEmpty && _auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(name);
    }
  }

  /// Mirrors a customer's name/phone into their registry row.
  ///
  /// Only the deterministic `customers/{uid}` row created at sign-up is
  /// updated. Legacy rows with generated ids are handled by the registry's
  /// "Sync Missing Accounts" action. Failures are swallowed because the
  /// profile update itself already succeeded.
  Future<void> _mirrorCustomerRegistryRow(
    String uid, {
    String? name,
    String? phoneNumber,
  }) async {
    if ((name == null || name.trim().isEmpty) && phoneNumber == null) return;
    try {
      final userDoc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(uid)
          .get();
      final role =
          (userDoc.data()?['role'] as String? ?? '').trim().toLowerCase();
      if (role != AppConstants.roleCustomer) return;

      final customerRef =
          _firestore.collection(AppConstants.collectionCustomers).doc(uid);
      final customerDoc = await customerRef.get();
      if (!customerDoc.exists) return;

      await customerRef.set(
        {
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (phoneNumber != null) 'contactNumber': phoneNumber.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal: the customer can still be matched by uid in the registry.
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Watch User Profile stream
  Stream<UserProfileModel?> watchUserProfile(String uid) {
    return _firestore
        .collection(AppConstants.collectionUsers)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfileModel.fromMap(doc.data()!);
    });
  }
}
