import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/form_validators.dart';

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
}
