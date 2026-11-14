/// Status helpers shared by the order and parcel features.
///
/// Parcel statuses are Title Case (`In Transit`) while `order_requests` stores
/// uppercase snake case (`IN_TRANSIT`). Comparing these raw values made status
/// changes silently miss the customer's order and the filter chips stop
/// matching, so every comparison goes through here.
library;

/// Lower-case snake-case form used for comparisons: `In Transit`, `IN_TRANSIT`
/// and `in-transit` all become `in_transit`.
String normalizeOrderStatus(Object? raw) {
  return (raw as String? ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');
}

/// The value written to `order_requests.status` when a parcel changes status.
///
/// Dispatch already stores `DISPATCHED`, so the synced values follow the same
/// uppercase snake-case convention.
String orderStatusFromParcel(String parcelStatus) =>
    normalizeOrderStatus(parcelStatus).toUpperCase();

/// Human-readable label for a stored status (`IN_TRANSIT` -> `IN TRANSIT`).
String formatOrderStatus(String status) => status.replaceAll('_', ' ');
