import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class ReturnModel {
  final String id;
  final String trackingNumber;
  final String platform; // Shopee, Lazada, TikTok Shop
  final String customerName;
  final String? contactNumber;
  final String
      defectReason; // Wrong Plate Number, Bent/Damaged, Printing Defect, etc.
  final String? customPlateDetails; // e.g., "Plate: ABC 1234 (Black, Embossed)"
  final String? notes;
  final List<String> photoUrls; // Cloudinary photo URLs
  final String
      status; // Pending Review, Approved, Replacement Dispatched, Refunded, Rejected
  final String resolutionType; // Replacement or Refund
  final String? replacementTrackingNumber;
  final String? handledById;
  final String? handledByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReturnModel({
    this.id = '',
    required this.trackingNumber,
    required this.platform,
    required this.customerName,
    this.contactNumber,
    required this.defectReason,
    this.customPlateDetails,
    this.notes,
    this.photoUrls = const [],
    required this.status,
    this.resolutionType = 'Replacement',
    this.replacementTrackingNumber,
    this.handledById,
    this.handledByName,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReturnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReturnModel(
      id: doc.id,
      trackingNumber: data['trackingNumber'] as String? ?? '',
      platform: data['platform'] as String? ?? AppConstants.platformShopee,
      customerName: data['customerName'] as String? ?? 'Customer',
      contactNumber: data['contactNumber'] as String?,
      defectReason:
          data['defectReason'] as String? ?? AppConstants.defectDamaged,
      customPlateDetails: data['customPlateDetails'] as String?,
      notes: data['notes'] as String?,
      photoUrls: List<String>.from(data['photoUrls'] as List<dynamic>? ?? []),
      status: data['status'] as String? ?? AppConstants.returnStatusPending,
      resolutionType: data['resolutionType'] as String? ?? 'Replacement',
      replacementTrackingNumber: data['replacementTrackingNumber'] as String?,
      handledById: data['handledById'] as String?,
      handledByName: data['handledByName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'trackingNumber': trackingNumber,
      'platform': platform,
      'customerName': customerName,
      'contactNumber': contactNumber,
      'defectReason': defectReason,
      'customPlateDetails': customPlateDetails,
      'notes': notes,
      'photoUrls': photoUrls,
      'status': status,
      'resolutionType': resolutionType,
      'replacementTrackingNumber': replacementTrackingNumber,
      'handledById': handledById,
      'handledByName': handledByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ReturnModel copyWith({
    String? status,
    String? resolutionType,
    String? replacementTrackingNumber,
    String? handledById,
    String? handledByName,
    List<String>? photoUrls,
    String? notes,
  }) {
    return ReturnModel(
      id: id,
      trackingNumber: trackingNumber,
      platform: platform,
      customerName: customerName,
      contactNumber: contactNumber,
      defectReason: defectReason,
      customPlateDetails: customPlateDetails,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      resolutionType: resolutionType ?? this.resolutionType,
      replacementTrackingNumber:
          replacementTrackingNumber ?? this.replacementTrackingNumber,
      handledById: handledById ?? this.handledById,
      handledByName: handledByName ?? this.handledByName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
