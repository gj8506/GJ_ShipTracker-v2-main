import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/domain/customer_model.dart';

void main() {
  group('CustomerModel.forAccount', () {
    test("uses the uid as the document id and QR payload", () {
      final customer = CustomerModel.forAccount(
        uid: 'uid-123',
        name: '  Jane Doe ',
        contactNumber: ' 09171234567 ',
      );

      expect(customer.id, 'uid-123');
      expect(customer.name, 'Jane Doe');
      expect(customer.contactNumber, '09171234567');
      expect(customer.linkedUid, 'uid-123');
      expect(customer.qrPayload, 'GJAS1:uid-123');
    });

    test('falls back to a readable name when none is supplied', () {
      final customer = CustomerModel.forAccount(uid: 'uid-1', name: '   ');
      expect(customer.name, 'Customer');
      expect(customer.linkedUid, 'uid-1');
    });
  });

  group('CustomerModel.toFirestore', () {
    test('stores the QR payload for a registry row', () {
      final customer = CustomerModel.forAccount(
        uid: 'uid-9',
        name: 'Buyer',
        contactNumber: '09170000000',
        createdAt: DateTime(2026, 1, 2),
      );

      final data = customer.toFirestore();

      expect(data['name'], 'Buyer');
      expect(data['linkedUid'], 'uid-9');
      expect(data['qrPayload'], 'GJAS1:uid-9');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('omits the QR payload for an admin row without an id', () {
      final customer = CustomerModel(
        name: 'Walk-in',
        contactNumber: '09171111111',
        address: 'Laguna',
        createdAt: DateTime(2026, 1, 2),
      );

      final data = customer.toFirestore();

      expect(data.containsKey('qrPayload'), isFalse);
    });
  });
}
