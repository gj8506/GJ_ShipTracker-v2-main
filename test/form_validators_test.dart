import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/form_validators.dart';

/// Runs [formatters] the way a text field does and returns the final text.
String _apply(List<TextInputFormatter> formatters, String text) {
  var value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  for (final formatter in formatters) {
    value = formatter.formatEditUpdate(TextEditingValue.empty, value);
  }
  return value.text;
}

void main() {
  group('validateTrackingNumber', () {
    test('accepts a 15-character tracking number', () {
      expect(validateTrackingNumber('SPX4572829R9E88'), isNull);
    });

    test('rejects an empty tracking number', () {
      expect(validateTrackingNumber(null), 'Enter tracking number');
      expect(validateTrackingNumber('   '), 'Enter tracking number');
    });

    test('rejects anything shorter or longer than 15 characters', () {
      expect(validateTrackingNumber('SPX4572829R9E8'),
          'Tracking number must be exactly 15 characters');
      expect(validateTrackingNumber('SPX4572829R9E888'),
          'Tracking number must be exactly 15 characters');
    });

    test('ignores surrounding spaces when counting', () {
      expect(validateTrackingNumber('  SPX4572829R9E88  '), isNull);
    });
  });

  group('validateContactNumber', () {
    test('accepts an 11-digit mobile number', () {
      expect(validateContactNumber('09171234567'), isNull);
    });

    test('requires a value when the field is required', () {
      expect(validateContactNumber(''), 'Enter contact number');
      expect(validateContactNumber(null), 'Enter contact number');
    });

    test('allows an empty optional field', () {
      expect(validateContactNumber('', required: false), isNull);
    });

    test('rejects numbers that are not 11 digits', () {
      expect(validateContactNumber('0917123456'),
          'Contact number must be 11 digits');
      expect(validateContactNumber('091712345678'),
          'Contact number must be 11 digits');
    });

    test('rejects letters and symbols pasted into the field', () {
      expect(validateContactNumber('0917-123-4567'),
          'Contact number must contain digits only');
      expect(validateContactNumber('0917ABC4567'),
          'Contact number must contain digits only');
    });
  });

  group('normalizeContactNumber', () {
    test('strips formatting characters', () {
      expect(normalizeContactNumber('0917-123-4567'), '09171234567');
    });

    test('converts the +63 country code to the local 0 prefix', () {
      expect(normalizeContactNumber('+63 917 123 4567'), '09171234567');
    });

    test('caps the value at 11 digits', () {
      expect(normalizeContactNumber('0917123456789012'), '09171234567');
    });

    test('handles null and empty values', () {
      expect(normalizeContactNumber(null), '');
      expect(normalizeContactNumber(''), '');
    });
  });

  group('validateShippingAddress', () {
    test('accepts an address at the 35-character limit', () {
      expect(validateShippingAddress('a' * kShippingAddressMaxLength), isNull);
    });

    test('allows an empty optional address', () {
      expect(validateShippingAddress('', required: false), isNull);
      expect(validateShippingAddress(null), isNull);
    });

    test('requires a value when the field is required', () {
      expect(validateShippingAddress('  ', required: true),
          'Enter delivery address');
    });

    test('rejects an address longer than 35 characters', () {
      expect(
        validateShippingAddress('a' * (kShippingAddressMaxLength + 1)),
        'Address must be 35 characters or fewer',
      );
    });
  });

  group('validateItemSpecs', () {
    test('accepts specs at the 35-character limit', () {
      expect(validateItemSpecs('a' * kItemSpecsMaxLength), isNull);
    });

    test('rejects specs longer than 35 characters', () {
      expect(
        validateItemSpecs('a' * (kItemSpecsMaxLength + 1)),
        'Items / plate specs must be 35 characters or fewer',
      );
    });

    test('allows an empty optional value', () {
      expect(validateItemSpecs('', required: false), isNull);
    });
  });

  group('validateOrderNotes', () {
    test('accepts notes at the 30-character limit', () {
      expect(validateOrderNotes('a' * kOrderNotesMaxLength), isNull);
    });

    test('allows empty notes', () {
      expect(validateOrderNotes(''), isNull);
      expect(validateOrderNotes(null), isNull);
    });

    test('rejects notes longer than 30 characters', () {
      expect(
        validateOrderNotes('a' * (kOrderNotesMaxLength + 1)),
        'Notes must be 30 characters or fewer',
      );
    });
  });

  group('limitLength', () {
    test('keeps short values untouched', () {
      expect(limitLength('Makati', 35), 'Makati');
      expect(limitLength(null, 35), '');
    });

    test('truncates long values to the limit', () {
      expect(limitLength('a' * 50, 35).length, 35);
      expect(limitLength('a' * 50, 30), 'a' * 30);
    });
  });

  group('input formatter limits', () {
    test('contact numbers stay numeric and stop at 11 digits', () {
      expect(_apply(contactNumberInputFormatters, '0917-123-4567'),
          '09171234567');
      expect(_apply(contactNumberInputFormatters, '0917123456789012'),
          '09171234567');
    });

    test('tracking numbers stop at 15 characters', () {
      expect(_apply(trackingNumberInputFormatters, 'SPX4572829R9E888999'),
          'SPX4572829R9E88');
    });

    test('shipping addresses stop at 35 characters', () {
      expect(_apply(shippingAddressInputFormatters, 'a' * 60), 'a' * 35);
    });

    test('items and plate specs stop at 35 characters', () {
      expect(_apply(itemSpecsInputFormatters, 'b' * 60), 'b' * 35);
    });

    test('order notes stop at 30 characters', () {
      expect(_apply(orderNotesInputFormatters, 'c' * 60), 'c' * 30);
    });
  });
}
