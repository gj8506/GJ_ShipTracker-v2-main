import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/services/dpa_service.dart';

void main() {
  group('DpaPolicy', () {
    test('falls back to the seed policy when the document is empty', () {
      final policy = DpaPolicy.fromMap(<String, dynamic>{});

      expect(policy.title, DpaPolicy.defaults.title);
      expect(policy.body, DpaPolicy.defaults.body);
      expect(policy.version, kDpaPolicyVersion);
      expect(policy.updatedLabel, 'Effective 2026');
    });

    test('reads an admin-published revision', () {
      final updatedAt = DateTime(2026, 5, 4, 9, 30);
      final policy = DpaPolicy.fromMap(<String, dynamic>{
        'title': 'Updated DPA',
        'body': 'A newer agreement body.',
        'version': 4,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': 'admin-uid',
      });

      expect(policy.title, 'Updated DPA');
      expect(policy.body, 'A newer agreement body.');
      expect(policy.version, 4);
      expect(policy.updatedAt, updatedAt);
      expect(policy.updatedBy, 'admin-uid');
      expect(policy.updatedLabel, 'Updated 2026-05-04');
    });

    test('rejects an invalid version and blank text', () {
      final policy = DpaPolicy.fromMap(<String, dynamic>{
        'title': '   ',
        'body': '',
        'version': 0,
      });

      expect(policy.title, DpaPolicy.defaults.title);
      expect(policy.body, DpaPolicy.defaults.body);
      expect(policy.version, kDpaPolicyVersion);
    });

    test('serialises the fields the gate and sign-up screen read', () {
      final policy = DpaPolicy(
        title: 'Policy',
        body: 'Body',
        version: 3,
        updatedAt: DateTime(2026, 1, 2),
        updatedBy: 'admin-uid',
      );

      final data = policy.toFirestore();

      expect(data['title'], 'Policy');
      expect(data['body'], 'Body');
      expect(data['version'], 3);
      expect(data['updatedBy'], 'admin-uid');
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('the seed policy is usable without Firestore', () {
      expect(DpaPolicy.defaults.body.length, greaterThan(200));
      expect(DpaPolicy.defaults.version, kDpaPolicyVersion);
    });
  });
}
