import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String contactNumber;
  final String address;
  final String type; // 'regular', 'repeat', 'reseller'
  final String? linkedUid;
  final DateTime createdAt;

  const CustomerModel({
    this.id = '',
    required this.name,
    required this.contactNumber,
    required this.address,
    this.type = 'regular',
    this.linkedUid,
    required this.createdAt,
  });

  // Secure QR payload: contains ONLY the prefixed ID
  String get qrPayload => 'GJAS1:$id';

  /// Registry row created when a customer account is registered.
  ///
  /// The document id is the Firebase uid, so the auto-generated QR payload
  /// (`GJAS1:<uid>`) is stable across retries and the Dispatch registry can
  /// resolve the row from the scanned code immediately.
  factory CustomerModel.forAccount({
    required String uid,
    required String name,
    String contactNumber = '',
    String address = '',
    String type = 'regular',
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: uid,
      name: name.trim().isEmpty ? 'Customer' : name.trim(),
      contactNumber: contactNumber.trim(),
      address: address.trim(),
      type: type,
      linkedUid: uid,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Customer',
      contactNumber: data['contactNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      type: data['type'] as String? ?? 'regular',
      linkedUid: data['linkedUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'contactNumber': contactNumber,
      'address': address,
      'type': type,
      'linkedUid': linkedUid,
      'createdAt': Timestamp.fromDate(createdAt),
      // Stored for admin/dispatch tooling. The app always derives the payload
      // from the document id, so a missing value is not a problem.
      if (id.isNotEmpty) 'qrPayload': qrPayload,
    };
  }

  CustomerModel copyWith({
    String? name,
    String? contactNumber,
    String? address,
    String? type,
    String? linkedUid,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      type: type ?? this.type,
      linkedUid: linkedUid ?? this.linkedUid,
      createdAt: createdAt,
    );
  }
}
