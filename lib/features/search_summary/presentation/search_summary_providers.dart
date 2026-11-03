import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer/data/models/order_request_model.dart';

/// Every order request in the system, newest first.
///
/// Firestore rules allow staff/admin to read the whole collection, which is
/// what the Search Summary needs to look up historical orders.
final allOrderRequestsStreamProvider =
    StreamProvider.autoDispose<List<OrderRequestModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('order_requests')
      .snapshots()
      .map((snapshot) {
    final orders = snapshot.docs
        .map((doc) => OrderRequestModel.fromFirestore(doc))
        .toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  });
});
