import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/email_service.dart';
import '../domain/user_profile_model.dart';
import '../../qr_customers/domain/customer_model.dart'; // Added import for customer synchronization

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ==========================================
  // SIGN IN WITH GOOGLE
  // ==========================================
  /// Authenticates with Google only. It never creates a Firestore profile:
  /// accounts must be created through the Sign Up screen first.
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

    // 3. Create a credential for Firebase
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase
    return await _auth.signInWithCredential(credential);
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

    await _createUserProfile(
      user,
      role,
      fullName: fullName ?? user.displayName,
      phoneNumber: phoneNumber,
    );

    return userCredential;
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
      final newCustomer = CustomerModel(
        name: displayName.isNotEmpty ? displayName : 'Customer',
        contactNumber: profile.phoneNumber ?? '',
        address: '',
        type: 'regular',
        linkedUid: user.uid,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('customers').add(newCustomer.toFirestore());
    }
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
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // Positional alias for signInWithEmailAndPassword
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
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
      final rawRole = role?.trim() ?? '';
      final assignedRole =
          rawRole.isEmpty ? AppConstants.roleCustomer : rawRole.toLowerCase();
      final isStaffRole = assignedRole == AppConstants.roleStaff;
      final normalizedPhone =
          (phoneNumber ?? '').trim().isEmpty ? null : phoneNumber!.trim();

      final profile = UserProfileModel(
        uid: user.uid,
        email: user.email ?? email.trim(),
        fullName: displayName,
        role: assignedRole,
        status: isStaffRole
            ? AppConstants.accountStatusPending
            : AppConstants.accountStatusActive,
        phoneNumber: normalizedPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.uid)
          .set(profile.toMap());

      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      // Sync to Customer Registry & QR system if role is customer
      if (assignedRole == AppConstants.roleCustomer) {
        final newCustomer = CustomerModel(
          name: displayName.isNotEmpty ? displayName : 'Customer',
          contactNumber: normalizedPhone ?? '',
          address: '',
          type: 'regular',
          linkedUid: user.uid,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('customers').add(newCustomer.toFirestore());
      }
    }

    return credential;
  }

  // Password reset. When the branded email worker is configured we send a
  // custom reset link from the verified domain; otherwise we fall back to
  // Firebase Auth's built-in reset email so the flow never breaks.
  Future<void> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    final emailService = EmailService();

    if (emailService.isConfigured) {
      try {
        await emailService.sendPasswordReset(email: trimmed);
        return;
      } catch (_) {
        // Fall through to Firebase Auth's reset email.
      }
    }

    await _auth.sendPasswordResetEmail(email: trimmed);
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

    if (name != null && name.isNotEmpty && _auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(name);
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
