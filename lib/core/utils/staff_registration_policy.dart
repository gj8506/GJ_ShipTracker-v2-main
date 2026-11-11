/// Shared business rules for staff registration and the admin approval queue.
///
/// Keeping the numbers in one place means the signup guard, the auto-reject
/// sweep, and the paginated approval screen can never drift apart.
class StaffRegistrationPolicy {
  StaffRegistrationPolicy._();

  /// Maximum number of staff applications accepted per calendar day. The
  /// eleventh applicant of the day is blocked before an account is created.
  static const int maxApplicationsPerDay = 10;

  /// Pending staff applications older than this are automatically rejected so
  /// stale sign-ups do not sit in the review queue forever.
  static const Duration autoRejectAfter = Duration(hours: 72);

  /// Number of pending staff registrations shown on one approval page.
  static const int approvalsPageSize = 10;

  /// Local-calendar-day key used for the daily application counter document,
  /// e.g. `2026-11-11`. Both the pre-check and the atomic reservation use it,
  /// so the counter rolls over at local midnight.
  static String dayKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// True once today's applications have reached [maxApplicationsPerDay].
  static bool isDailyLimitReached(int applicationsToday) =>
      applicationsToday >= maxApplicationsPerDay;

  /// True when a pending application has passed [autoRejectAfter].
  ///
  /// A profile without a creation timestamp is left in the queue rather than
  /// rejected blindly — admins can still review it manually.
  static bool isExpired(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return false;
    return (now ?? DateTime.now()).difference(createdAt) >= autoRejectAfter;
  }

  /// Reason stored on automatically rejected staff profiles.
  static String get autoRejectReason =>
      'Auto-rejected after ${autoRejectAfter.inHours} hours without review.';

  /// Human-readable policy used in the approval banner.
  static String get autoRejectDescription =>
      'Applications older than ${autoRejectAfter.inHours} hours are '
      'auto-rejected.';

  /// Number of approval pages needed for [itemCount] registrations.
  static int pageCount(int itemCount, {int pageSize = approvalsPageSize}) {
    if (itemCount <= 0) return 1;
    return (itemCount + pageSize - 1) ~/ pageSize;
  }

  /// Clamps [page] to a valid zero-based page index.
  static int clampPage(
    int page,
    int itemCount, {
    int pageSize = approvalsPageSize,
  }) {
    final pages = pageCount(itemCount, pageSize: pageSize);
    if (page < 0) return 0;
    if (page >= pages) return pages - 1;
    return page;
  }

  /// Returns the slice of [items] shown on zero-based [page].
  static List<T> pageSlice<T>(
    List<T> items,
    int page, {
    int pageSize = approvalsPageSize,
  }) {
    if (items.isEmpty) return <T>[];
    final safePage = clampPage(page, items.length, pageSize: pageSize);
    final start = safePage * pageSize;
    final end =
        (start + pageSize) > items.length ? items.length : start + pageSize;
    return items.sublist(start, end);
  }
}
