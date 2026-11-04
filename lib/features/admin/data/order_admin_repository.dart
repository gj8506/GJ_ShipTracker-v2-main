import 'package:cloud_firestore/cloud_firestore.dart';

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
