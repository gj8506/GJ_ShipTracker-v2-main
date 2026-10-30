import 'package:cloud_firestore/cloud_firestore.dart';

class OrderRequestModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String plateText;
  final String plateStyle;
  final String vehicleType;
  final String deliveryAddress;
  final String notes;
  final String
      status; // 'pending', 'approved', 'in_production', 'dispatched', 'delivered', 'cancelled'
  final double price;
  final String trackingNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const OrderRequestModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.plateText,
    required this.plateStyle,
    required this.vehicleType,
    required this.deliveryAddress,
    this.notes = '',
    this.status = 'pending',
    this.price = 0.0,
    this.trackingNumber = '',
    required this.createdAt,
    this.updatedAt,
  });

  // Cross-compatibility getters for alternative property access
  String get plateNumber => plateText;
  String get style => plateStyle;
  String get recipientName => customerName;
  String get recipientAddress => deliveryAddress;
  String get address => deliveryAddress;
  String get phone => customerPhone;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'plateText': plateText,
      'plateStyle': plateStyle,
      'vehicleType': vehicleType,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'status': status,
      'price': price,
      'trackingNumber': trackingNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory OrderRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return OrderRequestModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ??
          data['recipientName'] as String? ??
          'Valued Customer',
      customerPhone:
          data['customerPhone'] as String? ?? data['phone'] as String? ?? '',
      plateText: data['plateText'] as String? ??
          data['plateNumber'] as String? ??
          'ABC 1234',
      plateStyle: data['plateStyle'] as String? ??
          data['style'] as String? ??
          'Standard Embossed',
      vehicleType: data['vehicleType'] as String? ?? 'Sedan / SUV',
      deliveryAddress: data['deliveryAddress'] as String? ??
          data['recipientAddress'] as String? ??
          '',
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      trackingNumber: data['trackingNumber'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      updatedAt:
          data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  OrderRequestModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? plateText,
    String? plateStyle,
    String? vehicleType,
    String? deliveryAddress,
    String? notes,
    String? status,
    double? price,
    String? trackingNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderRequestModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      plateText: plateText ?? this.plateText,
      plateStyle: plateStyle ?? this.plateStyle,
      vehicleType: vehicleType ?? this.vehicleType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      price: price ?? this.price,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
