import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_format.dart';

class ParcelModel {
  final String id;
  final String trackingNumber;
  final String platform; // Shopee, Lazada, TikTok Shop
  final String? customerId; // ADDED: Links the QR ID to prevent duplicates
  // Links the parcel to the customer's submitted order request so status
  // changes can be mirrored onto `order_requests` (the only collection
  // customers are allowed to read).
  final String? orderRequestId;
  final String customerName;
  final String? contactNumber;
  final String? address;
  final String? items; // e.g. "Custom Plate: ABC 1234 (Black, Embossed)"
  final double amount;
  final String courier; // SPX Express, J&T, Flash, Ninja Van
  final String
      status; // Pending, Dispatched, In Transit, Delivered, Returned, Cancelled
  final String? notes;
  final String? dispatchedById;
  final String? dispatchedByName;
  final DateTime? dispatchedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ParcelModel({
    this.id = '',
    required this.trackingNumber,
    required this.platform,
    this.customerId,
    this.orderRequestId,
    required this.customerName,
    this.contactNumber,
    this.address,
    this.items,
    required this.amount,
    required this.courier,
    required this.status,
    this.notes,
    this.dispatchedById,
    this.dispatchedByName,
    this.dispatchedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory ParcelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ParcelModel(
      id: doc.id,
      trackingNumber: data['trackingNumber'] as String? ?? '',
      platform: data['platform'] as String? ?? AppConstants.platformShopee,
      customerId: data['customerId'] as String?,
      orderRequestId: data['orderRequestId'] as String?,
      customerName: data['customerName'] as String? ?? 'Customer',
      contactNumber: data['contactNumber'] as String?,
      address: data['address'] as String?,
      items: data['items'] as String?,
      // A corrupt or oversized value must never reach the UI, charts or
      // invoices; treat it as unknown (0) instead of rendering 1e+32.
      amount: sanitizeMoneyValue(data['amount']) ?? 0.0,
      courier: data['courier'] as String? ?? AppConstants.courierSPX,
      status: data['status'] as String? ?? AppConstants.statusPending,
      notes: data['notes'] as String?,
      dispatchedById: data['dispatchedById'] as String?,
      dispatchedByName: data['dispatchedByName'] as String?,
      dispatchedAt: (data['dispatchedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'trackingNumber': trackingNumber,
      'platform': platform,
      if (customerId != null) 'customerId': customerId,
      if (orderRequestId != null) 'orderRequestId': orderRequestId,
      'customerName': customerName,
      'contactNumber': contactNumber,
      'address': address,
      'items': items,
      'amount': amount,
      'courier': courier,
      'status': status,
      'notes': notes,
      'dispatchedById': dispatchedById,
      'dispatchedByName': dispatchedByName,
      'dispatchedAt':
          dispatchedAt != null ? Timestamp.fromDate(dispatchedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ParcelModel copyWith({
    String? status,
    String? dispatchedById,
    String? dispatchedByName,
    DateTime? dispatchedAt,
    String? notes,
  }) {
    return ParcelModel(
      id: id,
      trackingNumber: trackingNumber,
      platform: platform,
      customerId: customerId,
      orderRequestId: orderRequestId,
      customerName: customerName,
      contactNumber: contactNumber,
      address: address,
      items: items,
      amount: amount,
      courier: courier,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dispatchedById: dispatchedById ?? this.dispatchedById,
      dispatchedByName: dispatchedByName ?? this.dispatchedByName,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
