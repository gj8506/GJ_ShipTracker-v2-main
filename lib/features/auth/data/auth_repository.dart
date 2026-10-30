import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
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
  Future<UserCredential?> signInWithGoogle({String? defaultRole}) async {
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
    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);

    final User? user = userCredential.user;

    // 5. If first time signing in, initialize profile in Firestore
    if (user != null) {
      final userDoc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Default new users to customer if defaultRole is customer or unspecified
        final assignedRole = defaultRole ?? 'customer';
        final profile = UserProfileModel(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? '',
          role: assignedRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.collectionUsers)
            .doc(user.uid)
            .set(profile.toMap());

        // Sync to Customer Registry & QR system if role is customer
        if (assignedRole.toLowerCase() == 'customer') {
          final newCustomer = CustomerModel(
            name: user.displayName?.isNotEmpty == true
                ? user.displayName!
                : 'Customer',
            contactNumber: '',
            address: '',
            type: 'regular',
            linkedUid: user.uid,
            createdAt: DateTime.now(),
          );

          await _firestore
              .collection('customers')
              .add(newCustomer.toFirestore());
        }
      }
    }

    return userCredential;
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
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user != null) {
      final displayName = fullName ?? username ?? '';
      final assignedRole = role ?? 'customer';

      final profile = UserProfileModel(
        uid: user.uid,
        email: user.email ?? email.trim(),
        fullName: displayName,
        role: assignedRole,
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
      if (assignedRole.toLowerCase() == 'customer') {
        final newCustomer = CustomerModel(
          name: displayName.isNotEmpty ? displayName : 'Customer',
          contactNumber: '',
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

  // Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
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
