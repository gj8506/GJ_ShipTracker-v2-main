import 'package:flutter/services.dart';

/// Courier tracking numbers are printed as 15-character codes
/// (e.g. `SPX4572829R9E8`).
const int kTrackingNumberLength = 15;

/// Philippine mobile numbers are 11 digits (e.g. `09171234567`).
const int kContactNumberLength = 11;

/// Keeps the tracking-number fields at the courier's 15-character format and
/// blocks characters that can never appear in a tracking code.
final List<TextInputFormatter> trackingNumberInputFormatters =
    <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
  LengthLimitingTextInputFormatter(kTrackingNumberLength),
];

/// Keeps the contact-number fields numeric and at 11 digits.
final List<TextInputFormatter> contactNumberInputFormatters =
    <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(kContactNumberLength),
];

/// Validates a tracking number, which must be exactly 15 characters.
///
/// Returns a user-facing error string, or `null` when the value is valid.
String? validateTrackingNumber(String? value) {
  final tracking = (value ?? '').trim();
  if (tracking.isEmpty) return 'Enter tracking number';
  if (tracking.length != kTrackingNumberLength) {
    return 'Tracking number must be exactly $kTrackingNumberLength characters';
  }
  return null;
}

/// Validates a Philippine contact number: digits only, 11 characters.
///
/// The input formatters already block letters, but pasted or autofilled text
/// can bypass them, so the value is checked again here and a readable error is
/// returned instead of writing bad data to Firestore.
///
/// Set [required] to false for optional fields: an empty value is then valid,
/// but anything typed must still be 11 digits.
String? validateContactNumber(String? value, {bool required = true}) {
  final contact = (value ?? '').trim();
  if (contact.isEmpty) {
    return required ? 'Enter contact number' : null;
  }
  if (!RegExp(r'^\d+$').hasMatch(contact)) {
    return 'Contact number must contain digits only';
  }
  if (contact.length != kContactNumberLength) {
    return 'Contact number must be $kContactNumberLength digits';
  }
  return null;
}

/// Cleans a contact number that came from stored data or a scanned profile.
///
/// Keeps digits only, converts the `+63` prefix to the local `0` form, and
/// trims anything past the 11-digit limit so the field always starts valid.
String normalizeContactNumber(String? value) {
  var digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('63')) {
    digits = '0${digits.substring(2)}';
  }
  if (digits.length > kContactNumberLength) {
    digits = digits.substring(0, kContactNumberLength);
  }
  return digits;
}
