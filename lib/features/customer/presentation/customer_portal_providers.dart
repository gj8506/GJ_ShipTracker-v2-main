import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Centralized, secure live stream connecting directly to order_requests.
final customerOrdersStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('order_requests')
      .where('userId',
          isEqualTo: user.uid) // <-- THIS satisfies the security rules
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    // Sort descending in-memory to bypass composite index requirements
    list.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return list;
  });
});

// Active Orders Counter for the Home Screen
final customerActiveOrdersCountProvider = Provider.autoDispose<int>((ref) {
  final orders = ref.watch(customerOrdersStreamProvider).value ?? [];
  return orders.where((o) {
    final status = (o['status'] as String?)?.toLowerCase() ?? '';
    return status == 'pending' || status == 'in_production';
  }).length;
});
