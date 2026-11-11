import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/utils/staff_registration_policy.dart';

void main() {
  group('StaffRegistrationPolicy daily limit', () {
    test('blocks the eleventh application of the day', () {
      expect(StaffRegistrationPolicy.isDailyLimitReached(0), isFalse);
      expect(StaffRegistrationPolicy.isDailyLimitReached(9), isFalse);
      expect(StaffRegistrationPolicy.isDailyLimitReached(10), isTrue);
      expect(StaffRegistrationPolicy.isDailyLimitReached(11), isTrue);
    });

    test('day key is a zero-padded local calendar date', () {
      expect(
        StaffRegistrationPolicy.dayKey(DateTime(2026, 1, 5, 23, 59)),
        '2026-01-05',
      );
      expect(
        StaffRegistrationPolicy.dayKey(DateTime(2026, 11, 11, 0, 1)),
        '2026-11-11',
      );
    });
  });

  group('StaffRegistrationPolicy auto-reject', () {
    test('keeps fresh applications and profiles without a date', () {
      final now = DateTime(2026, 11, 11, 12);

      expect(
        StaffRegistrationPolicy.isExpired(
            now.subtract(const Duration(hours: 1)),
            now: now),
        isFalse,
      );
      expect(StaffRegistrationPolicy.isExpired(null, now: now), isFalse);
    });

    test('rejects applications older than the review window', () {
      final now = DateTime(2026, 11, 11, 12);

      expect(
        StaffRegistrationPolicy.isExpired(
          now.subtract(StaffRegistrationPolicy.autoRejectAfter),
          now: now,
        ),
        isTrue,
      );
      expect(
        StaffRegistrationPolicy.isExpired(
          now.subtract(const Duration(hours: 73)),
          now: now,
        ),
        isTrue,
      );
    });

    test('auto-reject reason mentions the configured window', () {
      expect(
        StaffRegistrationPolicy.autoRejectReason,
        contains('${StaffRegistrationPolicy.autoRejectAfter.inHours} hours'),
      );
    });
  });

  group('StaffRegistrationPolicy pagination', () {
    test('page count is at least one even with no items', () {
      expect(StaffRegistrationPolicy.pageCount(0), 1);
      expect(StaffRegistrationPolicy.pageCount(1), 1);
      expect(StaffRegistrationPolicy.pageCount(10), 1);
      expect(StaffRegistrationPolicy.pageCount(11), 2);
      expect(StaffRegistrationPolicy.pageCount(23), 3);
    });

    test('clampPage keeps the index inside the available pages', () {
      expect(StaffRegistrationPolicy.clampPage(-4, 23), 0);
      expect(StaffRegistrationPolicy.clampPage(0, 23), 0);
      expect(StaffRegistrationPolicy.clampPage(2, 23), 2);
      expect(StaffRegistrationPolicy.clampPage(9, 23), 2);
      expect(StaffRegistrationPolicy.clampPage(9, 0), 0);
    });

    test('pageSlice returns ten registrations per page', () {
      final items = List<int>.generate(23, (index) => index);

      expect(
        StaffRegistrationPolicy.pageSlice(items, 0),
        items.sublist(0, 10),
      );
      expect(
        StaffRegistrationPolicy.pageSlice(items, 1),
        items.sublist(10, 20),
      );
      expect(
        StaffRegistrationPolicy.pageSlice(items, 2),
        items.sublist(20, 23),
      );
    });

    test('pageSlice tolerates out-of-range and empty input', () {
      final items = List<int>.generate(3, (index) => index);

      expect(StaffRegistrationPolicy.pageSlice(const [], 4), isEmpty);
      expect(
        StaffRegistrationPolicy.pageSlice(items, 7),
        items.sublist(0, 3),
      );
    });
  });
}
