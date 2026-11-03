import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/customer/data/models/order_request_model.dart';
import 'package:gjandasher_shiptracker/features/parcels/domain/parcel_model.dart';
import 'package:gjandasher_shiptracker/features/search_summary/domain/search_summary_logic.dart';

ParcelModel _parcel({
  String tracking = 'TRK-1',
  String customer = 'Maria Santos',
  String? phone = '09171234567',
  String? address = 'Quezon City',
  String? items = 'Standard (Irregular Hexagon)',
  double amount = 100,
  String status = 'Delivered',
  DateTime? createdAt,
}) {
  return ParcelModel(
    trackingNumber: tracking,
    platform: 'Shopee',
    customerName: customer,
    contactNumber: phone,
    address: address,
    items: items,
    amount: amount,
    courier: 'SPX Express',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 11, 3, 10),
  );
}

OrderRequestModel _order({
  String id = 'order-1',
  String customer = 'Pedro Reyes',
  String phone = '09170000000',
  String plate = 'ABC 1234',
  String address = 'Cebu City',
  double price = 1200,
  String status = 'pending',
  DateTime? createdAt,
}) {
  return OrderRequestModel(
    id: id,
    customerId: '',
    customerName: customer,
    customerPhone: phone,
    plateText: plate,
    plateStyle: 'Standard (Irregular Hexagon)',
    vehicleType: 'Sedan / SUV',
    deliveryAddress: address,
    price: price,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 11, 3, 9),
  );
}

void main() {
  group('resolveSearchDateRange', () {
    test('all time has no bound', () {
      expect(resolveSearchDateRange(SearchDateMode.allTime, DateTime.now()),
          isNull);
    });

    test('day covers the full local day', () {
      final range = resolveSearchDateRange(
        SearchDateMode.day,
        DateTime(2026, 11, 3, 15, 45),
      )!;

      expect(range.start, DateTime(2026, 11, 3));
      expect(range.end, DateTime(2026, 11, 4));
      expect(range.contains(DateTime(2026, 11, 3, 0, 0, 1)), isTrue);
      expect(range.contains(DateTime(2026, 11, 3, 23, 59, 59)), isTrue);
      expect(range.contains(DateTime(2026, 11, 2, 23, 59, 59)), isFalse);
      expect(range.contains(DateTime(2026, 11, 4)), isFalse);
    });

    test('week runs Monday to Sunday', () {
      // 2026-11-03 is a Tuesday.
      final range = resolveSearchDateRange(
        SearchDateMode.week,
        DateTime(2026, 11, 3, 8),
      )!;

      expect(range.start, DateTime(2026, 11, 2)); // Monday
      expect(range.end, DateTime(2026, 11, 9)); // next Monday
      expect(range.contains(DateTime(2026, 11, 2)), isTrue);
      expect(range.contains(DateTime(2026, 11, 8, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 11, 1, 23, 59)), isFalse);
      expect(range.contains(DateTime(2026, 11, 9)), isFalse);
    });

    test('a Monday anchors its own week', () {
      final range = resolveSearchDateRange(
        SearchDateMode.week,
        DateTime(2026, 11, 2),
      )!;

      expect(range.start, DateTime(2026, 11, 2));
      expect(range.end, DateTime(2026, 11, 9));
    });

    test('a Sunday anchors the week that started six days earlier', () {
      final range = resolveSearchDateRange(
        SearchDateMode.week,
        DateTime(2026, 11, 8),
      )!;

      expect(range.start, DateTime(2026, 11, 2));
      expect(range.contains(DateTime(2026, 11, 8, 22)), isTrue);
    });
  });

  group('query matching', () {
    test('an empty query matches everything', () {
      expect(matchesSearchQuery('', ['anything']), isTrue);
      expect(matchesSearchQuery('   ', ['anything']), isTrue);
    });

    test('matching is case-insensitive and ignores blank fields', () {
      expect(matchesSearchQuery('maria', [null, '', 'Maria Santos']), isTrue);
      expect(matchesSearchQuery('MARIA', ['maria santos']), isTrue);
      expect(matchesSearchQuery('lazada', ['Shopee', '']), isFalse);
    });

    test('parcels match tracking, customer, phone, plate and status', () {
      final parcel = _parcel();

      expect(parcelMatchesQuery(parcel, 'trk-1'), isTrue);
      expect(parcelMatchesQuery(parcel, 'maria'), isTrue);
      expect(parcelMatchesQuery(parcel, '0917'), isTrue);
      expect(parcelMatchesQuery(parcel, 'hexagon'), isTrue);
      expect(parcelMatchesQuery(parcel, 'delivered'), isTrue);
      expect(parcelMatchesQuery(parcel, 'nonexistent'), isFalse);
    });

    test('orders match plate, customer, phone and status', () {
      final order = _order();

      expect(orderMatchesQuery(order, 'abc 1234'), isTrue);
      expect(orderMatchesQuery(order, 'pedro'), isTrue);
      expect(orderMatchesQuery(order, '09170000000'), isTrue);
      expect(orderMatchesQuery(order, 'pending'), isTrue);
      expect(orderMatchesQuery(order, 'cebu'), isTrue);
      expect(orderMatchesQuery(order, 'missing'), isFalse);
    });
  });

  group('SearchSummaryTotals', () {
    test('counts statuses and sums recorded value', () {
      final totals = SearchSummaryTotals.from(
        parcels: [
          _parcel(amount: 100, status: 'Delivered'),
          _parcel(amount: 250.5, status: 'Returned'),
          _parcel(amount: 50, status: 'Pending'),
        ],
        orders: [
          _order(price: 1200, status: 'pending'),
          _order(price: 800, status: 'in_production'),
          _order(price: 600, status: 'delivered'),
        ],
      );

      expect(totals.parcelCount, 3);
      expect(totals.deliveredParcelCount, 1);
      expect(totals.returnedParcelCount, 1);
      expect(totals.parcelValue, 400.5);
      expect(totals.orderCount, 3);
      expect(totals.pendingOrderCount, 2);
      expect(totals.orderValue, 2600);
      expect(totals.totalValue, 3000.5);
    });

    test('is empty when nothing matches', () {
      final totals = SearchSummaryTotals.from(parcels: [], orders: []);

      expect(totals.parcelCount, 0);
      expect(totals.orderCount, 0);
      expect(totals.totalValue, 0);
    });

    test('status matching ignores casing and padding', () {
      final totals = SearchSummaryTotals.from(
        parcels: [_parcel(status: '  DELIVERED ')],
        orders: [_order(status: ' In_Production ')],
      );

      expect(totals.deliveredParcelCount, 1);
      expect(totals.pendingOrderCount, 1);
    });
  });
}
