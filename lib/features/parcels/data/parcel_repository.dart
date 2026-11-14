import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/order_status.dart';
import '../domain/parcel_model.dart';

class ParcelRepository {
  final FirebaseFirestore _firestore;

  ParcelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _parcelsCol =>
      _firestore.collection(AppConstants.collectionParcels);

  CollectionReference get _ordersCol => _firestore.collection('order_requests');

  // Real-time stream of all parcels (newest first)
  Stream<List<ParcelModel>> getParcelsStream() {
    return _parcelsCol.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => ParcelModel.fromFirestore(doc))
            .toList());
  }

  // Real-time stream of a single parcel by ID
  Stream<ParcelModel?> getParcelByIdStream(String id) {
    return _parcelsCol.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ParcelModel.fromFirestore(doc);
    });
  }

  // Get single parcel by ID once
  Future<ParcelModel?> getParcelById(String id) async {
    final doc = await _parcelsCol.doc(id).get();
    if (!doc.exists) return null;
    return ParcelModel.fromFirestore(doc);
  }

  // Add new outbound parcel
  Future<String> addParcel(ParcelModel parcel) async {
    final ref = await _parcelsCol.add(parcel.toFirestore());
    return ref.id;
  }

  // Update status (Supports BOTH positional updateParcelStatus(id, status) and named arguments)
  Future<void> updateParcelStatus(
    String id,
    String status, {
    String? dispatchedById,
    String? dispatchedByName,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == AppConstants.statusDispatched) {
      updateData['dispatchedAt'] = FieldValue.serverTimestamp();
      if (dispatchedById != null) updateData['dispatchedById'] = dispatchedById;
      if (dispatchedByName != null) {
        updateData['dispatchedByName'] = dispatchedByName;
      }
    }

    await _parcelsCol.doc(id).update(updateData);

    // Customers cannot read `parcels` (Firestore rules restrict it to staff),
    // so "My Orders" is driven entirely by `order_requests`. Mirror the new
    // parcel status onto the linked order, otherwise the customer keeps seeing
    // the last status dispatch wrote until someone edits the order by hand.
    final parcelDoc = await _parcelsCol.doc(id).get();
    final parcelData = parcelDoc.data() as Map<String, dynamic>?;
    if (parcelData != null) {
      await _syncLinkedOrderStatus(parcelData, status);
      _triggerOrderStatusNotification(parcelData, status);
    }
  }

  // Mirrors a parcel status onto the customer's order request. The order is
  // matched by `orderRequestId` when the parcel was created from an order, and
  // otherwise by the tracking number. Failures are logged instead of thrown:
  // the parcel update already succeeded, and a missing/foreign order should not
  // make the status change look unsuccessful to staff.
  Future<void> _syncLinkedOrderStatus(
    Map<String, dynamic> parcelData,
    String newStatus,
  ) async {
    final normalizedStatus = orderStatusFromParcel(newStatus);

    final update = <String, dynamic>{
      // Order requests store statuses uppercased (`DISPATCHED`), while parcel
      // statuses are Title Case (`In Transit`).
      'status': normalizedStatus,
      // Keep the raw, human-readable value so the order can present it without
      // guessing how the uppercase form should be capitalised.
      'parcelStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == AppConstants.statusDelivered) {
      update['deliveredAt'] = FieldValue.serverTimestamp();
    }

    try {
      final orderRequestId =
          (parcelData['orderRequestId'] as String?)?.trim() ?? '';
      if (orderRequestId.isNotEmpty) {
        final orderDoc = await _ordersCol.doc(orderRequestId).get();
        if (orderDoc.exists) {
          await orderDoc.reference.update(update);
          return;
        }
      }

      final trackingNumber =
          (parcelData['trackingNumber'] as String?)?.trim() ?? '';
      if (trackingNumber.isEmpty) return;

      // Fallback for parcels dispatched before `orderRequestId` was stored.
      final matches = await _ordersCol
          .where('trackingNumber', isEqualTo: trackingNumber)
          .get();
      if (matches.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in matches.docs) {
        batch.update(doc.reference, update);
      }
      await batch.commit();
    } catch (e) {
      developer.log(
        'Failed to sync parcel status to the linked order request',
        name: 'parcel_repository',
        error: e,
      );
    }
  }

  // --- INTERNAL HELPER FOR CLOUDFLARE WEBHOOK ---
  Future<void> _triggerOrderStatusNotification(
    Map<String, dynamic> data,
    String newStatus,
  ) async {
    try {
      final customerId = data['customerId'];
      final trackingNumber = data['trackingNumber'] ?? 'Unknown';

      if (customerId != null && customerId.toString().isNotEmpty) {
        // 1. Fetch the customer's FCM token from the users collection
        final userDoc =
            await _firestore.collection('users').doc(customerId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          // 2. Send the webhook
          await http.post(
            Uri.parse(
                'https://shiptracker-fcm.artlorence-hveridiano.workers.dev/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': fcmToken,
              'title': 'Order Status Update',
              'body': 'Your parcel ($trackingNumber) is now $newStatus.',
            }),
          );
        }
      }
    } catch (e) {
      developer.log(
        'Failed to send order status push notification',
        name: 'parcel_repository',
        error: e,
      );
    }
  }
}
