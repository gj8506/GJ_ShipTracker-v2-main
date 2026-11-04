import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/order_pricing.dart';

void main() {
  group('validatePriceOverride', () {
    test('accepts pesos, thousands separators and spaces', () {
      final result = validatePriceOverride(' ₱ 1,450.50 ');

      expect(result.isValid, isTrue);
      expect(result.value, 1450.50);
    });

    test('rounds to the nearest centavo', () {
      expect(validatePriceOverride('99.995').value, 100.00);
      expect(validatePriceOverride('99.994').value, 99.99);
    });

    test('accepts zero and the maximum allowed price', () {
      expect(validatePriceOverride('0').value, 0);
      expect(validatePriceOverride('1,000,000').value, kMaxOrderPrice);
    });

    test('rejects missing, non-numeric, negative and oversized values', () {
      expect(validatePriceOverride('   ').isValid, isFalse);
      expect(validatePriceOverride('free').isValid, isFalse);
      expect(validatePriceOverride('-1').isValid, isFalse);
      expect(validatePriceOverride('1,000,000.01').isValid, isFalse);
      expect(validatePriceOverride('NaN').isValid, isFalse);
      expect(validatePriceOverride('Infinity').isValid, isFalse);
    });
  });

  group('resolveOrderPrice', () {
    test('prefers the admin/dispatch final amount', () {
      final order = <String, dynamic>{
        'finalAmount': 1750.50,
        'price': 1200.0,
        'estimatedPrice': 1200.0,
      };

      expect(resolveOrderPrice(order), 1750.50);
      expect(hasFinalPrice(order), isTrue);
    });

    test('falls back to the submitted estimate', () {
      final order = <String, dynamic>{
        'price': 1200.0,
        'estimatedPrice': 1200.0,
      };

      expect(resolveOrderPrice(order), 1200.0);
      expect(hasFinalPrice(order), isFalse);
    });

    test('returns null when no price has been recorded', () {
      expect(resolveOrderPrice(<String, dynamic>{}), isNull);
      expect(hasFinalPrice(<String, dynamic>{}), isFalse);
    });
  });
}
