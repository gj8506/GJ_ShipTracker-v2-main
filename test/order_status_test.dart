import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/order_status.dart';

void main() {
  group('normalizeOrderStatus', () {
    test('treats every casing and separator the same', () {
      expect(normalizeOrderStatus('In Transit'), 'in_transit');
      expect(normalizeOrderStatus('IN_TRANSIT'), 'in_transit');
      expect(normalizeOrderStatus('in-transit'), 'in_transit');
      expect(normalizeOrderStatus('  In   Transit  '), 'in_transit');
      expect(normalizeOrderStatus('DELIVERED'), 'delivered');
    });

    test('handles missing values', () {
      expect(normalizeOrderStatus(null), '');
      expect(normalizeOrderStatus(''), '');
    });
  });

  group('orderStatusFromParcel', () {
    test('writes the uppercase form used by order_requests', () {
      expect(orderStatusFromParcel('Dispatched'), 'DISPATCHED');
      expect(orderStatusFromParcel('In Transit'), 'IN_TRANSIT');
      expect(orderStatusFromParcel('Delivered'), 'DELIVERED');
      expect(orderStatusFromParcel('Cancelled'), 'CANCELLED');
    });
  });

  group('formatOrderStatus', () {
    test('restores the readable label', () {
      expect(formatOrderStatus('IN_TRANSIT'), 'IN TRANSIT');
      expect(formatOrderStatus('DISPATCHED'), 'DISPATCHED');
    });
  });

  group('status filter matching', () {
    test('a parcel-driven storing status matches its filter chip', () {
      // This is the bug: the parcel writes In Transit, the chip is
      // `in_transit`, and a raw string comparison never matched.
      const stored = 'IN_TRANSIT';
      for (final chip in ['in_transit', 'IN_TRANSIT', 'In Transit']) {
        expect(normalizeOrderStatus(stored), normalizeOrderStatus(chip));
      }
    });
  });
}
