import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/customer_model.dart';
import '../../parcels/domain/parcel_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _customersRef => _firestore.collection('customers');
  CollectionReference get _parcelsRef => _firestore.collection('parcels');

  // Stream all customers
  Stream<List<CustomerModel>> getCustomersStream() {
    return _customersRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList(),
        );
  }

  // Get customer by ID
  Future<CustomerModel?> getCustomerById(String customerId) async {
    final doc = await _customersRef.doc(customerId).get();
    if (!doc.exists) return null;
    return CustomerModel.fromFirestore(doc);
  }

  // Fetch customer's most recent parcel to pre-fill repeat orders
  Future<ParcelModel?> getMostRecentParcel(String customerName) async {
    try {
      final query = await _parcelsRef
          .where('customerName', isEqualTo: customerName)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ParcelModel.fromFirestore(query.docs.first);
      }
    } catch (_) {
      // Fallback in case of index delay
    }
    return null;
  }

  // Add customer
  Future<String> addCustomer(CustomerModel customer) async {
    final docRef = await _customersRef.add(customer.toFirestore());
    return docRef.id;
  }

  // Update customer
  Future<void> updateCustomer(CustomerModel customer) async {
    await _customersRef.doc(customer.id).update(customer.toFirestore());
  }

  // Delete customer (Admin only)
  Future<void> deleteCustomer(String customerId) async {
    await _customersRef.doc(customerId).delete();
  }
}
