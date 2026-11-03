import 'package:flutter/services.dart';

/// Courier tracking numbers are printed as 15-character codes
/// (e.g. `SPX4572829R9E8`).
const int kTrackingNumberLength = 15;

/// Philippine mobile numbers are 11 digits (e.g. `09171234567`).
const int kContactNumberLength = 11;

/// Shipping addresses are capped so a long address cannot break the dispatch
/// and customer-list row layouts. 100 characters comfortably fits a complete
/// Philippine address (`House/Unit No., Street, Barangay, City, Province`).
const int kShippingAddressMaxLength = 100;

/// Items / plate specification summaries share the same generous limit so a
/// generated summary (`STANDARD (IRREGULAR HEXAGON) | Reg: ... | Make: ...`)
/// is never cut off when it is loaded into the dispatch form.
const int kItemSpecsMaxLength = 100;

/// Optional order notes are capped so they never overflow a parcel card.
const int kOrderNotesMaxLength = 30;

/// Defect descriptions on return tickets need more room than order notes: the
/// photo alone rarely explains the problem.
const int kReturnNotesMaxLength = 150;

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

/// Caps a shipping address at [kShippingAddressMaxLength] characters.
final List<TextInputFormatter> shippingAddressInputFormatters =
    <TextInputFormatter>[
  LengthLimitingTextInputFormatter(kShippingAddressMaxLength),
];

/// Caps an items / plate-specs summary at [kItemSpecsMaxLength] characters.
final List<TextInputFormatter> itemSpecsInputFormatters = <TextInputFormatter>[
  LengthLimitingTextInputFormatter(kItemSpecsMaxLength),
];

/// Caps optional order notes at [kOrderNotesMaxLength] characters.
final List<TextInputFormatter> orderNotesInputFormatters = <TextInputFormatter>[
  LengthLimitingTextInputFormatter(kOrderNotesMaxLength),
];

/// Caps return-ticket defect descriptions at [kReturnNotesMaxLength]
/// characters.
final List<TextInputFormatter> returnNotesInputFormatters =
    <TextInputFormatter>[
  LengthLimitingTextInputFormatter(kReturnNotesMaxLength),
];

/// Trims [value] down to [maxLength] characters.
///
/// Used for values loaded from Firestore (existing customers, pending orders,
/// scanned profiles), which never passed through an input formatter and may be
/// longer than the current limit.
String limitLength(String? value, int maxLength) {
  final text = value ?? '';
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength);
}

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

/// Validates a shipping address against [kShippingAddressMaxLength].
///
/// Set [required] to false for optional fields: an empty value is then valid,
/// but anything typed must stay within the limit.
String? validateShippingAddress(String? value, {bool required = false}) {
  final address = (value ?? '').trim();
  if (address.isEmpty) {
    return required ? 'Enter delivery address' : null;
  }
  if (address.length > kShippingAddressMaxLength) {
    return 'Address must be $kShippingAddressMaxLength characters or fewer';
  }
  return null;
}

/// Validates an items / plate-specs summary against [kItemSpecsMaxLength].
String? validateItemSpecs(String? value, {bool required = false}) {
  final specs = (value ?? '').trim();
  if (specs.isEmpty) {
    return required ? 'Enter items or plate specs' : null;
  }
  if (specs.length > kItemSpecsMaxLength) {
    return 'Items / plate specs must be $kItemSpecsMaxLength characters or fewer';
  }
  return null;
}

/// Validates optional order notes against [kOrderNotesMaxLength].
String? validateOrderNotes(String? value) {
  final notes = (value ?? '').trim();
  if (notes.isEmpty) return null;
  if (notes.length > kOrderNotesMaxLength) {
    return 'Notes must be $kOrderNotesMaxLength characters or fewer';
  }
  return null;
}

/// Validates a return-ticket defect description against
/// [kReturnNotesMaxLength].
///
/// Set [required] to true where the description must not be blank.
String? validateReturnNotes(String? value, {bool required = false}) {
  final notes = (value ?? '').trim();
  if (notes.isEmpty) {
    return required ? 'Enter defect description' : null;
  }
  if (notes.length > kReturnNotesMaxLength) {
    return 'Defect description must be $kReturnNotesMaxLength characters or fewer';
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
