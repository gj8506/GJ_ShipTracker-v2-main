/// Validation for an admin-entered final order price.
///
/// Kept free of Flutter/Firebase imports so the rules can be unit tested and
/// reused by any admin pricing surface.
class PriceOverrideResult {
  const PriceOverrideResult.valid(double this.value) : error = null;
  const PriceOverrideResult.invalid(String this.error) : value = null;

  final double? value;
  final String? error;

  bool get isValid => error == null;
}

/// Upper bound for a single plate order. Guards against pasted values that
/// would otherwise make analytics and invoices nonsensical.
const double kMaxOrderPrice = 1000000;

/// Parses a price typed by the admin, accepting `₱`, thousands separators and
/// surrounding spaces. Values are rounded to the nearest centavo.
PriceOverrideResult validatePriceOverride(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[₱,\s]'), '');
  if (cleaned.isEmpty) {
    return const PriceOverrideResult.invalid('Enter the final price.');
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite) {
    return const PriceOverrideResult.invalid(
      'Enter a valid amount, for example 1450 or 1450.50.',
    );
  }
  if (parsed < 0) {
    return const PriceOverrideResult.invalid(
      'The final price cannot be negative.',
    );
  }
  if (parsed > kMaxOrderPrice) {
    return const PriceOverrideResult.invalid(
      'The final price must be ₱1,000,000 or less.',
    );
  }

  return PriceOverrideResult.valid((parsed * 100).roundToDouble() / 100);
}

/// The price a record currently displays, preferring an overridden final price
/// and falling back to the estimate submitted by the customer.
double? resolveOrderPrice(Map<String, dynamic> order) {
  for (final key in const ['finalAmount', 'price', 'estimatedPrice']) {
    final value = order[key];
    if (value is num) return value.toDouble();
  }
  return null;
}

/// True when [order] carries an admin/dispatch-confirmed final amount.
bool hasFinalPrice(Map<String, dynamic> order) => order['finalAmount'] is num;
