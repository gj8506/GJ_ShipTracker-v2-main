import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/staff_registration_policy.dart';
import '../../auth/domain/user_profile_model.dart';

class StaffApprovalResult {
  final bool emailSent;
  final String? emailError;

  const StaffApprovalResult({
    required this.emailSent,
    this.emailError,
  });
}

/// Admin/owner-only operations for reviewing staff registrations.
class StaffApprovalRepository {
  final FirebaseFirestore _firestore;
  final EmailService _emailService;

  StaffApprovalRepository({
    FirebaseFirestore? firestore,
    EmailService? emailService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _emailService = emailService ?? EmailService();

  /// Watches every staff profile and filters pending registrations locally.
  ///
  /// Filtering in memory avoids a composite index and also tolerates older
  /// profiles that stored the role as "Staff" instead of "staff".
  Stream<List<UserProfileModel>> watchPendingStaff() {
    return _firestore
        .collection(AppConstants.collectionUsers)
        .where('role', whereIn: const ['staff', 'Staff'])
        .snapshots()
        .map((snapshot) {
          final pending = snapshot.docs
              .map((doc) => UserProfileModel.fromMap(doc.data()))
              .where((profile) => profile.isStaff && profile.isPending)
              .toList();

          pending.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aDate.compareTo(bDate);
          });

          return pending;
        });
  }

  /// Automatically rejects pending staff applications that have been waiting
  /// longer than [StaffRegistrationPolicy.autoRejectAfter].
  ///
  /// This runs client-side whenever an admin opens the Staff Approvals screen,
  /// so stale sign-ups disappear from the queue without requiring a scheduled
  /// Cloud Function. Returns the number of profiles rejected.
  Future<int> autoRejectExpiredStaff({DateTime? now}) async {
    final snapshot = await _firestore
        .collection(AppConstants.collectionUsers)
        .where('role', whereIn: const ['staff', 'Staff']).get();

    final expired = snapshot.docs.where((doc) {
      final profile = UserProfileModel.fromMap(doc.data());
      return profile.isStaff &&
          profile.isPending &&
          StaffRegistrationPolicy.isExpired(profile.createdAt, now: now);
    }).toList();

    if (expired.isEmpty) return 0;

    final reason = StaffRegistrationPolicy.autoRejectReason;

    // Firestore allows at most 500 writes per batch; 400 leaves headroom.
    const chunkSize = 400;
    for (var start = 0; start < expired.length; start += chunkSize) {
      final batch = _firestore.batch();
      for (final doc in expired.skip(start).take(chunkSize)) {
        batch.update(doc.reference, {
          'status': AppConstants.accountStatusRejected,
          'approvedBy': FieldValue.delete(),
          'approvedAt': FieldValue.delete(),
          'rejectedBy': 'system',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    return expired.length;
  }

  /// Marks a staff account active and sends the approval email.
  ///
  /// The Firestore update is the source of truth; a failed email does not
  /// roll back the approval. The caller receives [StaffApprovalResult] so it
  /// can warn the admin to resend or check the worker configuration.
  Future<StaffApprovalResult> approveStaff({
    required UserProfileModel staff,
    required String adminUid,
  }) async {
    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(staff.uid)
        .update({
      'status': AppConstants.accountStatusActive,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': FieldValue.delete(),
      'rejectedBy': FieldValue.delete(),
      'rejectedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _emailService.sendStaffApproved(
        to: staff.email,
        name: staff.fullName,
      );
      return const StaffApprovalResult(emailSent: true);
    } catch (e) {
      return StaffApprovalResult(
        emailSent: false,
        emailError: e.toString(),
      );
    }
  }

  Future<void> rejectStaff({
    required UserProfileModel staff,
    required String adminUid,
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();

    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(staff.uid)
        .update({
      'status': AppConstants.accountStatusRejected,
      'approvedBy': FieldValue.delete(),
      'approvedAt': FieldValue.delete(),
      'rejectedBy': adminUid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': (trimmedReason == null || trimmedReason.isEmpty)
          ? FieldValue.delete()
          : trimmedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retries the approval email without changing the account status. Useful
  /// when the first attempt failed because the email worker was misconfigured.
  Future<StaffApprovalResult> resendApprovalEmail(
    UserProfileModel staff,
  ) async {
    try {
      await _emailService.sendStaffApproved(
        to: staff.email,
        name: staff.fullName,
      );
      return const StaffApprovalResult(emailSent: true);
    } catch (e) {
      return StaffApprovalResult(emailSent: false, emailError: e.toString());
    }
  }
}
