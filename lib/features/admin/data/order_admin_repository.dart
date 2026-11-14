import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/money_format.dart';

/// Writes the admin-approved final price for an order request.
abstract class OrderAdminRepository {
  Future<void> updateFinalPrice({
    required String orderId,
    required double amount,
    required String adminUid,
    required String adminName,
  });
}

class FirestoreOrderAdminRepository implements OrderAdminRepository {
  FirestoreOrderAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> updateFinalPrice({
    required String orderId,
    required double amount,
    required String adminUid,
    required String adminName,
  }) async {
    // Defence in depth: the dialog validates the field, but a direct call must
    // not be able to persist a chart-breaking value.
    if (!amount.isFinite || amount < 0 || amount > kMaxMoneyAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Final price must be between ₱0 and ₱999,999,999.',
      );
    }

    await _firestore.collection('order_requests').doc(orderId).update({
      // `finalAmount` is what the customer invoice shows; `price` keeps the
      // summaries, analytics and search totals in step with the override.
      'finalAmount': amount,
      'price': amount,
      'finalPriceOverridden': true,
      'finalPriceUpdatedAt': FieldValue.serverTimestamp(),
      'finalPriceUpdatedBy': adminUid,
      'finalPriceUpdatedByName': adminName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
