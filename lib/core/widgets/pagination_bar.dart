import 'package:flutter/material.dart';

/// Client-side pagination footer shared by the Parcel Dashboard, Customer
/// Registry and Staff Approvals screens.
///
/// All slicing happens in memory on the already-filtered list, so search and
/// date filters keep working exactly as before. Numbered page pills live inside
/// a [Wrap] so a long queue can never overflow horizontally, and the
/// Previous / Next controls stay full-width on phones.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.itemCount,
    required this.pageSize,
    required this.onPageChanged,
    this.itemLabel = 'items',
  }) : assert(pageSize > 0, 'pageSize must be greater than zero');

  /// Zero-based index of the page currently shown.
  final int page;

  /// Total number of pages, always at least one.
  final int pageCount;

  /// Total number of filtered items across every page.
  final int itemCount;

  /// Number of items shown on one page.
  final int pageSize;

  /// Called with the zero-based index of the page the user picked.
  final ValueChanged<int> onPageChanged;

  /// Plural noun used in the "Showing X–Y of Z <itemLabel>" summary.
  final String itemLabel;

  /// Number of pages needed to show [itemCount] items.
  static int pageCountFor(int itemCount, int pageSize) {
    if (itemCount <= 0 || pageSize <= 0) return 1;
    return (itemCount + pageSize - 1) ~/ pageSize;
  }

  /// Clamps [page] to a valid zero-based page index.
  static int clampPage(int page, int itemCount, int pageSize) {
    final pages = pageCountFor(itemCount, pageSize);
    if (page < 0) return 0;
    if (page >= pages) return pages - 1;
    return page;
  }

  /// Returns the slice of [items] shown on zero-based [page].
  static List<T> pageSlice<T>(List<T> items, int page, int pageSize) {
    if (items.isEmpty) return <T>[];
    final safePage = clampPage(page, items.length, pageSize);
    final start = safePage * pageSize;
    final end =
        (start + pageSize) > items.length ? items.length : start + pageSize;
    return items.sublist(start, end);
  }

  /// Page indexes to render as numbered pills. Short lists show every page;
  /// longer lists show a five-page window around the current page.
  List<int> get _visiblePages {
    if (pageCount <= 7) {
      return List<int>.generate(pageCount, (index) => index);
    }
    final start = (page - 2).clamp(0, pageCount - 5);
    return List<int>.generate(5, (index) => start + index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safePage = clampPage(page, itemCount, pageSize);
    final first = itemCount == 0 ? 0 : safePage * pageSize + 1;
    final last = ((safePage + 1) * pageSize).clamp(0, itemCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Showing $first–$last of $itemCount $itemLabel',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final index in _visiblePages)
                _PagePill(
                  pageNumber: index + 1,
                  selected: index == safePage,
                  onTap: () => onPageChanged(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      safePage > 0 ? () => onPageChanged(safePage - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: safePage < pageCount - 1
                      ? () => onPageChanged(safePage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  const _PagePill({
    required this.pageNumber,
    required this.selected,
    required this.onTap,
  });

  final int pageNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Page $pageNumber',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Page $pageNumber',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
