import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/money_format.dart';

void main() {
  group('sanitizeMoneyValue', () {
    test('accepts finite, non-negative amounts below the cap', () {
      expect(sanitizeMoneyValue(0), 0);
      expect(sanitizeMoneyValue(1450.5), 1450.5);
      expect(sanitizeMoneyValue('1,200'), isNull, reason: 'commas are not num');
      expect(sanitizeMoneyValue('999999999'), kMaxMoneyAmount);
    });

    test('rejects the corrupt value that froze analytics', () {
      expect(sanitizeMoneyValue(1e32), isNull);
      expect(sanitizeMoneyValue(1000000000), isNull);
      expect(sanitizeMoneyValue(double.infinity), isNull);
      expect(sanitizeMoneyValue(double.nan), isNull);
      expect(sanitizeMoneyValue(-1), isNull);
      expect(sanitizeMoneyValue('not-a-number'), isNull);
      expect(sanitizeMoneyValue(null), isNull);
    });
  });

  group('formatMoney', () {
    test('renders exact pesos for normal amounts', () {
      expect(formatMoney(0), '₱0.00');
      expect(formatMoney(1450.5), '₱1,450.50');
    });

    test('renders a dash instead of a chart-breaking number', () {
      expect(formatMoney(1e32), '—');
      expect(formatMoney(1e20), '—');
      expect(formatMoney(double.nan), '—');
      expect(formatMoney(-5), '—');
      expect(formatMoney(null), '—');
    });

    test('abbreviates aggregate totals above the record cap', () {
      expect(formatMoney(1000000000), '₱1B');
      expect(formatMoney(2500000000), '₱2.5B');
    });
  });

  group('formatMoneyShort', () {
    test('keeps cents below one million and abbreviates above it', () {
      expect(formatMoneyShort(400), '₱400.00');
      expect(formatMoneyShort(999999), '₱999,999.00');
      expect(formatMoneyShort(1000000), '₱1M');
      expect(formatMoneyShort(1250000), '₱1.3M');
      expect(formatMoneyShort(999999999), '₱1B');
    });
  });

  group('formatMoneyCompact', () {
    test('produces short bounded labels', () {
      expect(formatMoneyCompact(500), '₱500');
      expect(formatMoneyCompact(1500), '₱1.5K');
      expect(formatMoneyCompact(2500000), '₱2.5M');
      expect(formatMoneyCompact(1e32), '—');
    });
  });

  group('MoneyInputFormatter', () {
    const formatter = MoneyInputFormatter();

    TextEditingValue type(String text, {String previous = ''}) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: previous),
        TextEditingValue(text: text),
      );
    }

    test('strips grouping separators and the peso sign', () {
      expect(type('₱ 1,750.50').text, '1750.50');
    });

    test('blocks scientific notation and letters', () {
      expect(type('1e32', previous: '1').text, '1');
      expect(type('abc', previous: '12').text, '12');
      expect(type('-50', previous: '').text, '');
    });

    test('caps whole digits at nine and decimals at two', () {
      expect(type('1234567890123').text, '123456789');
      expect(type('123.456').text, '123.45');
    });

    test('accepts an in-progress decimal point', () {
      expect(type('123.').text, '123.');
      expect(type('0.5').text, '0.5');
    });
  });

  group('validateMoneyInput', () {
    test('accepts normal, formatted and boundary amounts', () {
      expect(validateMoneyInput('1450'), isNull);
      expect(validateMoneyInput('₱ 1,450.50'), isNull);
      expect(validateMoneyInput('999999999'), isNull);
      expect(validateMoneyInput('0'), isNull);
    });

    test('rejects empty, negative, scientific and oversized values', () {
      expect(validateMoneyInput(''), isNotNull);
      expect(validateMoneyInput('-1'), isNotNull);
      expect(validateMoneyInput('1e32'), isNotNull);
      expect(validateMoneyInput('1000000000'), isNotNull);
      expect(validateMoneyInput('12.345'), isNotNull);
    });

    test('optional fields accept an empty value', () {
      expect(validateMoneyInput('', required: false), isNull);
    });
  });
}
