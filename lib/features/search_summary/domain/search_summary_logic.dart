import '../../customer/data/models/order_request_model.dart';
import '../../parcels/domain/parcel_model.dart';

/// How the Search Summary narrows history by date.
enum SearchDateMode {
  allTime,
  day,
  week,
}

/// A half-open date range: [start] is inclusive, [end] is exclusive.
class SearchDateRange {
  const SearchDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);

  int get dayCount => end.difference(start).inDays;
}

/// Resolves the range for [mode] around [anchor].
///
/// Weeks run Monday to Sunday (Philippine convention), and both bounds are
/// normalised to local midnight so a timestamp at 11:59 PM still matches.
SearchDateRange? resolveSearchDateRange(
  SearchDateMode mode,
  DateTime anchor,
) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);

  switch (mode) {
    case SearchDateMode.allTime:
      return null;
    case SearchDateMode.day:
      return SearchDateRange(
        start: day,
        end: day.add(const Duration(days: 1)),
      );
    case SearchDateMode.week:
      final monday =
          day.subtract(Duration(days: day.weekday - DateTime.monday));
      return SearchDateRange(
        start: monday,
        end: monday.add(const Duration(days: 7)),
      );
  }
}

/// Case-insensitive match against any of the supplied fields.
///
/// An empty query matches everything, and null/blank fields are ignored so a
/// missing contact number never hides an otherwise valid result.
bool matchesSearchQuery(String query, Iterable<String?> fields) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;

  return fields.any((field) {
    final haystack = (field ?? '').trim().toLowerCase();
    return haystack.isNotEmpty && haystack.contains(needle);
  });
}

bool parcelMatchesQuery(ParcelModel parcel, String query) {
  return matchesSearchQuery(query, [
    parcel.trackingNumber,
    parcel.customerName,
    parcel.contactNumber,
    parcel.address,
    parcel.items,
    parcel.platform,
    parcel.courier,
    parcel.status,
    parcel.notes,
  ]);
}

bool orderMatchesQuery(OrderRequestModel order, String query) {
  return matchesSearchQuery(query, [
    order.trackingNumber,
    order.customerName,
    order.customerPhone,
    order.plateText,
    order.plateStyle,
    order.vehicleType,
    order.deliveryAddress,
    order.status,
    order.notes,
  ]);
}

/// Headline totals for the Search Summary cards.
class SearchSummaryTotals {
  const SearchSummaryTotals({
    required this.parcelCount,
    required this.deliveredParcelCount,
    required this.returnedParcelCount,
    required this.parcelValue,
    required this.orderCount,
    required this.pendingOrderCount,
    required this.orderValue,
  });

  factory SearchSummaryTotals.from({
    required List<ParcelModel> parcels,
    required List<OrderRequestModel> orders,
  }) {
    var delivered = 0;
    var returned = 0;
    var parcelValue = 0.0;

    for (final parcel in parcels) {
      parcelValue += parcel.amount;
      switch (parcel.status.trim().toLowerCase()) {
        case 'delivered':
          delivered++;
          break;
        case 'returned':
          returned++;
          break;
      }
    }

    var pendingOrders = 0;
    var orderValue = 0.0;

    for (final order in orders) {
      orderValue += order.price;
      final status = order.status.trim().toLowerCase();
      if (status == 'pending' || status == 'in_production') {
        pendingOrders++;
      }
    }

    return SearchSummaryTotals(
      parcelCount: parcels.length,
      deliveredParcelCount: delivered,
      returnedParcelCount: returned,
      parcelValue: parcelValue,
      orderCount: orders.length,
      pendingOrderCount: pendingOrders,
      orderValue: orderValue,
    );
  }

  final int parcelCount;
  final int deliveredParcelCount;
  final int returnedParcelCount;
  final double parcelValue;

  final int orderCount;
  final int pendingOrderCount;
  final double orderValue;

  double get totalValue => parcelValue + orderValue;
}
