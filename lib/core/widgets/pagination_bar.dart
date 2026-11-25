import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Client-side pagination footer shared by the Parcel Dashboard, Customer
/// Registry and Staff Approvals screens.
///
/// All slicing happens in memory on the already-filtered list, so search and
/// date filters keep working exactly as before.
///
/// The control is a single compact line — `Back 1 2 3 4 5 Next` — with the
/// selected page filled by the theme's primary colour. Gap markers ("…") stand
/// in for pages hidden by the five-page window. A [FittedBox] keeps the whole
/// row on one line even on a narrow phone, and every colour comes from the
/// active [ColorScheme] so the bar follows light/dark theme changes instantly.
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

  /// Plural noun used in the "Showing X–Y of Z <itemLabel>" accessibility
  /// label. The visible control itself shows only page numbers.
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
    final visiblePages = _visiblePages;
    final showLeadingGap = visiblePages.isNotEmpty && visiblePages.first > 0;
    final showTrailingGap =
        visiblePages.isNotEmpty && visiblePages.last < pageCount - 1;
    final enabledColor = scheme.primary;
    final disabledColor = scheme.onSurfaceVariant.withValues(alpha: 0.35);

    // Compact `Back 1 2 3 4 5 Next` row. The count stays available to screen
    // readers but no longer takes up space above the controls.
    return Semantics(
      container: true,
      label: 'Showing $first–$last of $itemCount $itemLabel',
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PageArrow(
                label: 'Back',
                enabled: safePage > 0,
                color: safePage > 0 ? enabledColor : disabledColor,
                onTap: safePage > 0 ? () => onPageChanged(safePage - 1) : null,
              ),
              const SizedBox(width: 8),
              if (showLeadingGap) ...[
                const _PageGap(),
                const SizedBox(width: 2),
              ],
              for (final index in visiblePages) ...[
                _PagePill(
                  pageNumber: index + 1,
                  selected: index == safePage,
                  onTap: () => onPageChanged(index),
                ),
                const SizedBox(width: 2),
              ],
              if (showTrailingGap) ...[
                const _PageGap(),
                const SizedBox(width: 2),
              ],
              _PageArrow(
                label: 'Next',
                enabled: safePage < pageCount - 1,
                color: safePage < pageCount - 1 ? enabledColor : disabledColor,
                onTap: safePage < pageCount - 1
                    ? () => onPageChanged(safePage + 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain text step control used for Back / Next in the compact pagination row.
class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.label,
    required this.enabled,
    required this.color,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$pageNumber',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in for pages hidden by the five-page window. Purely visual, so it is
/// not tappable and is excluded from the accessibility tree.
class _PageGap extends StatelessWidget {
  const _PageGap();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 14,
        height: 30,
        child: Center(
          child: Text(
            '…',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PREVIEW ENTRY POINT
// ---------------------------------------------------------------------------
// This file can be launched on its own from Android Studio (press the green
// run arrow next to `main` below) or from a terminal:
//
//     flutter run -t lib/core/widgets/pagination_bar.dart
//
// The real app still starts from `lib/main.dart`; the preview below only
// renders the shared footer so its layout can be checked on a phone without
// Firebase, auth or push-notification setup.

void main() => runApp(const _PaginationBarPreviewApp());

class _PaginationBarPreviewApp extends StatefulWidget {
  const _PaginationBarPreviewApp();

  @override
  State<_PaginationBarPreviewApp> createState() =>
      _PaginationBarPreviewAppState();
}

class _PaginationBarPreviewAppState extends State<_PaginationBarPreviewApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaginationBar preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(_dark ? Brightness.dark : Brightness.light),
      home: _PaginationBarPreviewScreen(
        dark: _dark,
        onToggleTheme: () => setState(() => _dark = !_dark),
      ),
    );
  }
}

class _PaginationBarPreviewScreen extends StatefulWidget {
  const _PaginationBarPreviewScreen({
    required this.dark,
    required this.onToggleTheme,
  });

  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  State<_PaginationBarPreviewScreen> createState() =>
      _PaginationBarPreviewScreenState();
}

class _PaginationBarPreviewScreenState
    extends State<_PaginationBarPreviewScreen> {
  static const int _pageSize = 10;

  /// Defaults to the 79-parcel dashboard from the bug report.
  int _itemCount = 79;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = PaginationBar.pageCountFor(_itemCount, _pageSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PaginationBar preview'),
        actions: [
          IconButton(
            tooltip: 'Toggle light / dark',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Total parcels',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 24, label: Text('24')),
                ButtonSegment(value: 79, label: Text('79')),
                ButtonSegment(value: 120, label: Text('120')),
              ],
              selected: {_itemCount},
              onSelectionChanged: (selection) => setState(() {
                _itemCount = selection.first;
                _page = 0;
              }),
            ),
            const SizedBox(height: 24),
            PaginationBar(
              page: _page,
              pageCount: pageCount,
              itemCount: _itemCount,
              pageSize: _pageSize,
              itemLabel: 'parcels',
              onPageChanged: (page) => setState(() => _page = page),
            ),
          ],
        ),
      ),
    );
  }
}
