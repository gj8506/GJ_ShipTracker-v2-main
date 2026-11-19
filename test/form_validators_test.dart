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
    test('accepts an address at the configured character limit', () {
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

    test('accepts a full Philippine address', () {
      expect(
        validateShippingAddress(
          '123 Rizal St., Brgy. Poblacion, Nagcarlan, Laguna',
          required: true,
        ),
        isNull,
      );
    });

    test('rejects an address longer than the configured limit', () {
      expect(
        validateShippingAddress('a' * (kShippingAddressMaxLength + 1)),
        'Address must be $kShippingAddressMaxLength characters or fewer',
      );
    });
  });

  group('validateItemSpecs', () {
    test('accepts specs at the configured limit', () {
      expect(validateItemSpecs('a' * kItemSpecsMaxLength), isNull);
    });

    test('accepts a generated plate summary', () {
      expect(
        validateItemSpecs(
          'STANDARD (IRREGULAR HEXAGON) | Reg: REGION 12 | Make: HONDA',
        ),
        isNull,
      );
    });

    test('rejects specs longer than the configured limit', () {
      expect(
        validateItemSpecs('a' * (kItemSpecsMaxLength + 1)),
        'Items / plate specs must be $kItemSpecsMaxLength characters or fewer',
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

  group('validateMotorcycleBrand', () {
    test('accepts common brands and empty optional values', () {
      expect(validateMotorcycleBrand('MOTORSTAR'), isNull);
      expect(validateMotorcycleBrand('HONDA'), isNull);
      expect(validateMotorcycleBrand(''), isNull);
      expect(validateMotorcycleBrand(null), isNull);
    });

    test('requires a brand when asked', () {
      expect(
        validateMotorcycleBrand('  ', required: true),
        'Enter the motorcycle brand',
      );
    });

    test('accepts a brand at the configured limit', () {
      expect(
        validateMotorcycleBrand('a' * kMotorcycleBrandMaxLength),
        isNull,
      );
    });

    test('rejects a brand longer than the configured limit', () {
      expect(
        validateMotorcycleBrand('a' * (kMotorcycleBrandMaxLength + 1)),
        'Motorcycle brand must be '
        '$kMotorcycleBrandMaxLength characters or fewer',
      );
    });
  });

  group('validatePlateSpecs', () {
    test('accepts specs at the 30-character limit', () {
      expect(validatePlateSpecs('a' * kPlateSpecsMaxLength), isNull);
      expect(validatePlateSpecs('White plate, embossed'), isNull);
    });

    test('allows an empty optional value', () {
      expect(validatePlateSpecs('', required: false), isNull);
      expect(validatePlateSpecs(null), isNull);
    });

    test('requires specs when asked', () {
      expect(validatePlateSpecs('  ', required: true),
          'Enter items or plate specs');
    });

    test('rejects specs longer than the configured limit', () {
      expect(
        validatePlateSpecs('a' * (kPlateSpecsMaxLength + 1)),
        'Plate specifications must be '
        '$kPlateSpecsMaxLength characters or fewer',
      );
    });
  });

  group('validateCustomerName', () {
    test('accepts names at the 60-character limit', () {
      expect(validateCustomerName('a' * kCustomerNameMaxLength), isNull);
      expect(validateCustomerName('Maria Santos'), isNull);
    });

    test('allows an empty optional value', () {
      expect(validateCustomerName(''), isNull);
      expect(validateCustomerName(null), isNull);
    });

    test('requires a name when asked', () {
      expect(validateCustomerName('  ', required: true), 'Enter customer name');
    });

    test('rejects a name longer than the configured limit', () {
      expect(
        validateCustomerName('a' * (kCustomerNameMaxLength + 1)),
        'Customer name must be $kCustomerNameMaxLength characters or fewer',
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

  group('validateReturnNotes', () {
    test('accepts a description at the configured limit', () {
      expect(validateReturnNotes('a' * kReturnNotesMaxLength), isNull);
    });

    test('allows an empty optional description', () {
      expect(validateReturnNotes(''), isNull);
      expect(validateReturnNotes(null), isNull);
    });

    test('requires a description when asked', () {
      expect(validateReturnNotes('  ', required: true),
          'Enter defect description');
    });

    test('rejects a description longer than the configured limit', () {
      expect(
        validateReturnNotes('a' * (kReturnNotesMaxLength + 1)),
        'Defect description must be $kReturnNotesMaxLength characters or fewer',
      );
    });
  });

  group('input formatter limits', () {
    test('contact numbers stay numeric and stop at 11 digits', () {
      expect(
          _apply(contactNumberInputFormatters, '0917-123-4567'), '09171234567');
      expect(_apply(contactNumberInputFormatters, '0917123456789012'),
          '09171234567');
    });

    test('tracking numbers stop at 15 characters', () {
      expect(_apply(trackingNumberInputFormatters, 'SPX4572829R9E888999'),
          'SPX4572829R9E88');
    });

    test('shipping addresses stop at the configured limit', () {
      expect(
        _apply(shippingAddressInputFormatters, 'a' * 150),
        'a' * kShippingAddressMaxLength,
      );
    });

    test('items and plate specs stop at the configured limit', () {
      expect(
        _apply(itemSpecsInputFormatters, 'b' * 150),
        'b' * kItemSpecsMaxLength,
      );
    });

    test('order notes stop at 30 characters', () {
      expect(_apply(orderNotesInputFormatters, 'c' * 60), 'c' * 30);
    });

    test('return descriptions stop at the configured limit', () {
      expect(
        _apply(returnNotesInputFormatters, 'd' * 200),
        'd' * kReturnNotesMaxLength,
      );
    });

    test('motorcycle brands stop at 20 characters', () {
      expect(
        _apply(motorcycleBrandInputFormatters, 'MOTORSTARSUPERLONGNAME'),
        'MOTORSTARSUPERLONGNAME'.substring(0, kMotorcycleBrandMaxLength),
      );
      expect(
        _apply(motorcycleBrandInputFormatters, 'a' * 60),
        'a' * kMotorcycleBrandMaxLength,
      );
    });

    test('customer names stop at 60 characters', () {
      expect(
        _apply(customerNameInputFormatters, 'a' * 100),
        'a' * kCustomerNameMaxLength,
      );
    });

    test('plate specifications stop at 30 characters', () {
      expect(
        _apply(plateSpecsInputFormatters, 'b' * 80),
        'b' * kPlateSpecsMaxLength,
      );
    });
  });
}
