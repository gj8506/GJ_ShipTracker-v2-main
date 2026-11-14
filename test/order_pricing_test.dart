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
      expect(validatePriceOverride('999,999,999').value, kMaxOrderPrice);
      expect(kMaxOrderPrice, lessThan(1000000000));
    });

    test('rejects missing, non-numeric, negative and oversized values', () {
      expect(validatePriceOverride('   ').isValid, isFalse);
      expect(validatePriceOverride('free').isValid, isFalse);
      expect(validatePriceOverride('-1').isValid, isFalse);
      expect(validatePriceOverride('1,000,000,000').isValid, isFalse);
      expect(validatePriceOverride('NaN').isValid, isFalse);
      expect(validatePriceOverride('Infinity').isValid, isFalse);
    });

    test('rejects scientific notation that used to break analytics', () {
      // `double.tryParse` happily returns 1e32 for this, which is exactly how
      // the corrupt parcel amount reached Firestore.
      expect(validatePriceOverride('1e32').isValid, isFalse);
      expect(validatePriceOverride('1E9').isValid, isFalse);
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

    test('ignores corrupt or absurd stored amounts', () {
      final order = <String, dynamic>{
        'finalAmount': 1e32,
        'price': double.infinity,
        'estimatedPrice': 1200.0,
      };

      // The bad values are skipped rather than rendered as "₱1e+32".
      expect(resolveOrderPrice(order), 1200.0);
      expect(hasFinalPrice(order), isFalse);

      expect(
        resolveOrderPrice(<String, dynamic>{'finalAmount': 'not-a-number'}),
        isNull,
      );
      expect(
        resolveOrderPrice(<String, dynamic>{'price': -5}),
        isNull,
      );
    });
  });
}
