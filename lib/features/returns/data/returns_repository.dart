import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_paths.dart';
import '../domain/return_model.dart';

class ReturnsRepository {
  final FirebaseFirestore _firestore;

  ReturnsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _returnsCol =>
      _firestore.collection(FirestorePaths.returns);

  // Real-time stream of all returns ordered by newest first
  Stream<List<ReturnModel>> getReturnsStream() {
    return _returnsCol.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => ReturnModel.fromFirestore(doc))
            .toList());
  }

  // Get a single return ticket by ID
  Future<ReturnModel?> getReturnById(String id) async {
    final doc = await _returnsCol.doc(id).get();
    if (!doc.exists) return null;
    return ReturnModel.fromFirestore(doc);
  }

  // Real-time stream for a single return ticket
  Stream<ReturnModel?> getReturnByIdStream(String id) {
    return _returnsCol.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReturnModel.fromFirestore(doc);
    });
  }

  // Create new return ticket
  Future<String> createReturn(ReturnModel returnModel) async {
    final ref = await _returnsCol.add(returnModel.toFirestore());
    return ref.id;
  }

  // Update return status & resolution details
  Future<void> updateReturnStatus({
    required String id,
    required String status,
    String? resolutionType,
    String? replacementTrackingNumber,
    String? handledById,
    String? handledByName,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (resolutionType != null) {
      updateData['resolutionType'] = resolutionType;
    }
    if (replacementTrackingNumber != null &&
        replacementTrackingNumber.isNotEmpty) {
      updateData['replacementTrackingNumber'] =
          replacementTrackingNumber.trim();
    }
    if (handledById != null) updateData['handledById'] = handledById;
    if (handledByName != null) updateData['handledByName'] = handledByName;

    await _returnsCol.doc(id).update(updateData);
  }
}
