import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_admin_repository.dart';

/// Every order request, newest first, as raw maps so the admin screen can read
/// the estimate, final price and audit fields together.
final adminOrderRequestsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('order_requests')
      .snapshots()
      .map((snapshot) {
    final orders = snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
    // Sorted in memory to avoid a composite index requirement.
    orders.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return orders;
  });
});

final orderAdminRepositoryProvider = Provider<OrderAdminRepository>((ref) {
  return FirestoreOrderAdminRepository();
});
