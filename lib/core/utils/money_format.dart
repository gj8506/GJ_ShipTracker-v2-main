import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Shared money rules for every amount the app accepts, stores or renders.
///
/// A single plate order or a parcel's declared value can never legitimately
/// reach a billion pesos. Accepting larger values (or scientific notation such
/// as `1e32`) used to poison Analytics: the running totals became enormous and
/// the chart axis, metric tiles and order cards all tried to render a
/// 300-character number.
///
/// Nine digits keeps amounts below ₱1,000,000,000, which is comfortably above
/// real order totals (including million-peso months) while staying small enough
/// for charts and cards to draw instantly.
const double kMaxMoneyAmount = 999999999;

/// Maximum number of digits the user can type before the decimal point.
const int kMaxMoneyIntegerDigits = 9;

/// Maximum number of digits allowed after the decimal point.
const int kMoneyDecimalDigits = 2;

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

/// Converts a raw Firestore value into a safe amount.
///
/// Returns `null` for missing, non-numeric, non-finite, negative or oversized
/// values. Callers can then decide whether to skip the record (Analytics), show
/// a dash, or fall back to zero.
double? sanitizeMoneyValue(Object? raw) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim());
  }

  if (value == null || !value.isFinite) return null;
  if (value < 0) return null;
  if (value > kMaxMoneyAmount) return null;
  return value;
}

/// Largest value that will be rendered at all. Anything above this is treated
/// as corrupt data (1e+32) rather than a real total.
const double _maxDisplayableAmount = 1e15;

/// Returns a renderable amount, or `null` for corrupt input.
double? _displayableAmount(num? value) {
  final amount = value?.toDouble();
  if (amount == null ||
      !amount.isFinite ||
      amount < 0 ||
      amount > _maxDisplayableAmount) {
    return null;
  }
  return amount;
}

/// Exact peso rendering such as `₱1,450.50`.
///
/// Single records are capped at [kMaxMoneyAmount]; a number above that is
/// either corrupt or an aggregate total, so it is shown compactly instead of
/// printing a wall of digits. Truly absurd values (`1e+32`) render as an em
/// dash so they can never break a layout.
String formatMoney(num? value) {
  final amount = _displayableAmount(value);
  if (amount == null) return '—';
  if (amount > kMaxMoneyAmount) return formatMoneyCompact(amount);
  return _currencyFormat.format(amount);
}

/// Bounded currency rendering for tight spaces such as list rows and tiles.
///
/// Values below one million keep their cents; larger values collapse to a short
/// suffix (`₱1.2M`) so a ₱999,999,999 order still fits on a phone card.
String formatMoneyShort(num? value) {
  final amount = _displayableAmount(value);
  if (amount == null) return '—';
  if (amount < 1000000) return _currencyFormat.format(amount);
  return formatMoneyCompact(amount);
}

/// Compact peso rendering used for chart axes and summary chips.
String formatMoneyCompact(num? value) {
  final amount = _displayableAmount(value);
  if (amount == null) return '—';

  // Rounding can push an amount to the next unit (999.6M -> 1000M), so the
  // thresholds sit slightly below each boundary.
  if (amount >= 999500000) {
    if (amount >= 999500000000) {
      return '₱${_scaled(amount / 1000000000000)}T';
    }
    return '₱${_scaled(amount / 1000000000)}B';
  }
  if (amount >= 999500) {
    return '₱${_scaled(amount / 1000000)}M';
  }
  if (amount >= 1000) {
    return '₱${_scaled(amount / 1000)}K';
  }
  return '₱${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
}

String _scaled(double scaled) {
  final text =
      scaled >= 100 ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1);
  return _trimZero(text);
}

String _trimZero(String text) =>
    text.endsWith('.0') ? text.substring(0, text.length - 2) : text;

/// Normalises a typed amount: digits and at most one decimal point, capped at
/// [kMaxMoneyIntegerDigits] whole digits and [kMoneyDecimalDigits] decimals.
///
/// Commas, spaces and the peso sign are stripped so pasted values such as
/// `₱ 1,750.50` still work, while letters and scientific notation (`1e32`) are
/// rejected outright.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({
    this.maxIntegerDigits = kMaxMoneyIntegerDigits,
    this.decimalDigits = kMoneyDecimalDigits,
  });

  final int maxIntegerDigits;
  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.replaceAll(RegExp(r'[,\s₱]'), '');

    if (cleaned.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(cleaned)) {
      // Letters, minus signs and exponents are never valid money input.
      return oldValue;
    }

    final dotIndex = cleaned.indexOf('.');
    var whole = dotIndex == -1 ? cleaned : cleaned.substring(0, dotIndex);
    var fraction = dotIndex == -1 ? '' : cleaned.substring(dotIndex + 1);

    if (whole.length > maxIntegerDigits) {
      whole = whole.substring(0, maxIntegerDigits);
    }
    if (fraction.length > decimalDigits) {
      fraction = fraction.substring(0, decimalDigits);
    }

    final text = cleaned.contains('.') ? '$whole.$fraction' : whole;

    if (text == newValue.text) return newValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Input formatters for every money field.
final List<TextInputFormatter> moneyInputFormatters = <TextInputFormatter>[
  const MoneyInputFormatter(),
];

/// Validates a typed amount against [kMaxMoneyAmount].
///
/// Returns `null` when valid, otherwise a short message suitable for an
/// `InputDecoration.errorText`.
String? validateMoneyInput(
  String? raw, {
  bool required = true,
  String label = 'amount',
}) {
  final cleaned = (raw ?? '').replaceAll(RegExp(r'[₱,\s]'), '');
  if (cleaned.isEmpty) {
    return required ? 'Enter the $label.' : null;
  }

  // Reject anything that is not plain digits with up to two decimals. This
  // catches scientific notation, signs and stray characters that
  // `double.tryParse` would otherwise accept.
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(cleaned)) {
    return 'Enter a valid $label, for example 1450 or 1450.50.';
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite) {
    return 'Enter a valid $label, for example 1450 or 1450.50.';
  }
  if (parsed > kMaxMoneyAmount) {
    return 'The $label must be ₱999,999,999 or less.';
  }
  return null;
}
