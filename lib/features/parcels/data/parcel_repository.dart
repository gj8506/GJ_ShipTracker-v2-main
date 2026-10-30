import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import '../../../core/constants/app_constants.dart';
import '../domain/parcel_model.dart';

class ParcelRepository {
  final FirebaseFirestore _firestore;

  ParcelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _parcelsCol =>
      _firestore.collection(AppConstants.collectionParcels);

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

    // TRIGGER NOTIFICATION AFTER SUCCESSFUL STATUS UPDATE
    _triggerOrderStatusNotification(id, status);
  }

  // --- INTERNAL HELPER FOR CLOUDFLARE WEBHOOK ---
  Future<void> _triggerOrderStatusNotification(
      String parcelId, String newStatus) async {
    try {
      // 1. Fetch the parcel to get customer ID and tracking number
      final parcelDoc = await _parcelsCol.doc(parcelId).get();
      if (!parcelDoc.exists) return;

      final data = parcelDoc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final customerId = data['customerId'];
      final trackingNumber = data['trackingNumber'] ?? 'Unknown';

      if (customerId != null && customerId.toString().isNotEmpty) {
        // 2. Fetch the customer's FCM token from the users collection
        final userDoc =
            await _firestore.collection('users').doc(customerId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          // 3. Send the webhook
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
