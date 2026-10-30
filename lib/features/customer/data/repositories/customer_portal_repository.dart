import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_request_model.dart';

class CustomerPortalRepository {
  final FirebaseFirestore _firestore;

  CustomerPortalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('order_requests');

  CollectionReference<Map<String, dynamic>> get _parcelsRef =>
      _firestore.collection('parcels');

  /// Create a new plate order request
  Future<String> submitOrderRequest(OrderRequestModel request) async {
    final docRef = _ordersRef.doc();
    final modelWithId = request.copyWith(id: docRef.id);
    await docRef.set(modelWithId.toMap());
    return docRef.id;
  }

  /// Real-time stream of orders for the active customer
  Stream<List<OrderRequestModel>> watchCustomerOrderRequests(
      String customerId) {
    if (customerId.isEmpty) {
      return Stream.value([]);
    }

    return _ordersRef
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderRequestModel.fromFirestore(doc))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Real-time stream of parcels matched by customer ID (outbound shipments)
  Stream<List<Map<String, dynamic>>> watchCustomerParcels(String customerId) {
    if (customerId.isEmpty) {
      return Stream.value([]);
    }

    return _parcelsRef
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  /// Update order status
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (trackingNumber != null && trackingNumber.isNotEmpty) {
      updateData['trackingNumber'] = trackingNumber;
    }
    await _ordersRef.doc(orderId).update(updateData);
  }
}
