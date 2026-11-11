import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/staff_registration_policy.dart';

/// Raised when today's staff application cap has already been reached.
class StaffApplicationLimitException implements Exception {
  final String message;

  const StaffApplicationLimitException([
    this.message = AppConstants.staffApplicationLimitMessage,
  ]);

  @override
  String toString() => message;
}

/// Enforces the daily staff application cap using a small aggregate document.
///
/// Firestore rules do not let a brand-new (or signed-out) applicant read other
/// user profiles, so counting `users` directly would either fail or leak data.
/// Instead each day has one counter document containing only `count` and the
/// date key. The signup screen pre-checks it and the repository reserves a slot
/// atomically before the staff profile is written.
///
/// If the counter collection cannot be read or written yet (for example the
/// updated Firestore rules have not been deployed), the limiter fails open so
/// staff registration keeps working. A real limit hit always fails closed.
class StaffRegistrationLimiter {
  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  StaffRegistrationLimiter({
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  DocumentReference<Map<String, dynamic>> _dayRef(String dayKey) {
    return _firestore
        .collection(AppConstants.collectionStaffRegistrationDays)
        .doc(dayKey);
  }

  int _readCount(Map<String, dynamic>? data) {
    final value = data?['count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Number of staff applications already recorded for today.
  Future<int> todayApplicationCount() async {
    final day = StaffRegistrationPolicy.dayKey(_clock());
    final snapshot = await _dayRef(day).get();
    return _readCount(snapshot.data());
  }

  /// Friendly pre-check used before creating a Firebase Auth account.
  ///
  /// Throws [StaffApplicationLimitException] when the cap is reached. Counter
  /// infrastructure failures are treated as "allowed" so a rules deployment
  /// delay cannot block sign-ups; [reserveSlot] is still authoritative.
  Future<void> assertCanApply() async {
    int count;
    try {
      count = await todayApplicationCount();
    } catch (error) {
      debugPrint(
        '⚠️ [StaffRegistrationLimiter] Could not read today\'s counter, '
        'allowing the application: $error',
      );
      return;
    }

    if (StaffRegistrationPolicy.isDailyLimitReached(count)) {
      throw const StaffApplicationLimitException();
    }
  }

  /// Atomically claims one of today's application slots.
  ///
  /// The transaction makes concurrent sign-ups safe: two applicants cannot both
  /// take the last slot. Call this immediately before writing a staff profile.
  /// A real limit hit throws [StaffApplicationLimitException]; transient
  /// counter errors fail open as described above.
  Future<void> reserveSlot() async {
    final day = StaffRegistrationPolicy.dayKey(_clock());
    final ref = _dayRef(day);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final count = _readCount(snapshot.data());

        if (StaffRegistrationPolicy.isDailyLimitReached(count)) {
          throw const StaffApplicationLimitException();
        }

        if (snapshot.exists) {
          transaction.update(ref, {
            'count': count + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(ref, {
            'day': day,
            'count': 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on StaffApplicationLimitException {
      rethrow;
    } catch (error) {
      debugPrint(
        '⚠️ [StaffRegistrationLimiter] Could not reserve a slot, allowing '
        'the application: $error',
      );
    }
  }
}
