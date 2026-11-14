import 'money_format.dart';

/// Validation for an admin-entered final order price.
///
/// Kept free of Firebase imports so the rules can be unit tested and reused by
/// any admin pricing surface.
class PriceOverrideResult {
  const PriceOverrideResult.valid(double this.value) : error = null;
  const PriceOverrideResult.invalid(String this.error) : value = null;

  final double? value;
  final String? error;

  bool get isValid => error == null;
}

/// Upper bound for a single plate order.
///
/// Shared with every other money field (`kMaxMoneyAmount`): nine digits stays
/// below one billion pesos, which keeps totals readable on order cards and
/// stops a single mistyped value from making Analytics sluggish.
const double kMaxOrderPrice = kMaxMoneyAmount;

/// Parses a price typed by the admin, accepting `₱`, thousands separators and
/// surrounding spaces. Values are rounded to the nearest centavo.
///
/// Scientific notation (`1e32`) and signed values are rejected outright rather
/// than parsed, because they are never legitimate prices and used to produce
/// chart-breaking totals.
PriceOverrideResult validatePriceOverride(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[₱,\s]'), '');

  if (cleaned.isEmpty) {
    return const PriceOverrideResult.invalid('Enter the final price.');
  }

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) {
    return const PriceOverrideResult.invalid(
      'Enter a valid amount, for example 1450 or 1450.50.',
    );
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite) {
    return const PriceOverrideResult.invalid(
      'Enter a valid amount, for example 1450 or 1450.50.',
    );
  }
  if (parsed > kMaxOrderPrice) {
    return const PriceOverrideResult.invalid(
      'The final price must be ₱999,999,999 or less.',
    );
  }

  return PriceOverrideResult.valid((parsed * 100).roundToDouble() / 100);
}

/// The price a record currently displays, preferring an overridden final price
/// and falling back to the estimate submitted by the customer.
///
/// Corrupt values (non-numeric, non-finite, negative or above the money cap)
/// are ignored so one bad document cannot break every order card.
double? resolveOrderPrice(Map<String, dynamic> order) {
  for (final key in const ['finalAmount', 'price', 'estimatedPrice']) {
    final value = sanitizeMoneyValue(order[key]);
    if (value != null) return value;
  }
  return null;
}

/// True when [order] carries an admin/dispatch-confirmed final amount.
bool hasFinalPrice(Map<String, dynamic> order) =>
    sanitizeMoneyValue(order['finalAmount']) != null;
