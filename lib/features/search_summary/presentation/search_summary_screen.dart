import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../customer/data/models/order_request_model.dart';
import '../../parcels/domain/parcel_model.dart';
import '../../parcels/presentation/parcel_providers.dart';
import '../domain/search_summary_logic.dart';
import 'search_summary_providers.dart';

/// Admin/staff lookup screen for historical parcels and order requests.
///
/// The query box searches every identifying field on a record, and the date
/// filter narrows history to a single day or a Monday–Sunday week.
class SearchSummaryScreen extends ConsumerStatefulWidget {
  const SearchSummaryScreen({super.key});

  @override
  ConsumerState<SearchSummaryScreen> createState() =>
      _SearchSummaryScreenState();
}

class _SearchSummaryScreenState extends ConsumerState<SearchSummaryScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  SearchDateMode _dateMode = SearchDateMode.allTime;
  DateTime _anchorDate = DateTime.now();

  static final DateFormat _dayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _shortDayFormat = DateFormat('MMM d');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SearchDateRange? get _dateRange =>
      resolveSearchDateRange(_dateMode, _anchorDate);

  bool get _isTodaySelected {
    if (_dateMode != SearchDateMode.day) return false;
    final now = DateTime.now();
    return _sameDay(_anchorDate, now);
  }

  bool get _isThisWeekSelected {
    if (_dateMode != SearchDateMode.week) return false;
    final now = DateTime.now();
    final range = resolveSearchDateRange(SearchDateMode.week, now)!;
    return range.contains(_anchorDate);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _clearDateFilter() {
    setState(() {
      _dateMode = SearchDateMode.allTime;
      _anchorDate = DateTime.now();
    });
  }

  void _selectToday() {
    setState(() {
      _dateMode = SearchDateMode.day;
      _anchorDate = DateTime.now();
    });
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Filter by a specific date',
      initialDate: _dateMode == SearchDateMode.day ? _anchorDate : now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dateMode = SearchDateMode.day;
      _anchorDate = picked;
    });
  }

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Pick any day in the week to show',
      initialDate: _dateMode == SearchDateMode.week ? _anchorDate : now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dateMode = SearchDateMode.week;
      _anchorDate = picked;
    });
  }

  String _rangeLabel(SearchDateRange range) {
    if (_dateMode == SearchDateMode.day) {
      return _dayFormat.format(range.start);
    }
    final lastDay = range.end.subtract(const Duration(days: 1));
    return '${_shortDayFormat.format(range.start)} – '
        '${_dayFormat.format(lastDay)}';
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(parcelsStreamProvider);
    final ordersAsync = ref.watch(allOrderRequestsStreamProvider);

    final allParcels = parcelsAsync.value ?? const <ParcelModel>[];
    final allOrders = ordersAsync.value ?? const <OrderRequestModel>[];
    final range = _dateRange;

    final parcels = allParcels
        .where((parcel) =>
            (range == null || range.contains(parcel.createdAt)) &&
            parcelMatchesQuery(parcel, _query))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final orders = allOrders
        .where((order) =>
            (range == null || range.contains(order.createdAt)) &&
            orderMatchesQuery(order, _query))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totals = SearchSummaryTotals.from(parcels: parcels, orders: orders);
    final isLoading = parcelsAsync.isLoading || ordersAsync.isLoading;
    final error = parcelsAsync.error ?? ordersAsync.error;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Search Summary',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh history',
            onPressed: () {
              ref.invalidate(parcelsStreamProvider);
              ref.invalidate(allOrderRequestsStreamProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search tracking no., plate, customer, phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      ),
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _dateChip(
                  label: 'All time',
                  selected: _dateMode == SearchDateMode.allTime,
                  onSelected: _clearDateFilter,
                ),
                const SizedBox(width: 8),
                _dateChip(
                  label: 'Today',
                  selected: _isTodaySelected,
                  onSelected: _selectToday,
                ),
                const SizedBox(width: 8),
                _dateChip(
                  label: 'Pick date',
                  icon: Icons.event_outlined,
                  selected:
                      _dateMode == SearchDateMode.day && !_isTodaySelected,
                  onSelected: _pickSpecificDate,
                ),
                const SizedBox(width: 8),
                _dateChip(
                  label: 'Pick week',
                  icon: Icons.date_range_outlined,
                  selected: _isThisWeekSelected,
                  onSelected: _pickWeek,
                ),
              ],
            ),
          ),
          if (range != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available_rounded,
                        size: 18, color: AppColors.navyPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _rangeLabel(range),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearDateFilter,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Parcels',
                    value: '${totals.parcelCount}',
                    subtitle: '${totals.deliveredParcelCount} delivered • '
                        '${totals.returnedParcelCount} returned',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Orders',
                    value: '${totals.orderCount}',
                    subtitle: '${totals.pendingOrderCount} pending',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navyPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 18, color: AppColors.textOnPrimary),
                  const SizedBox(width: 8),
                  const Text(
                    'Recorded value',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatMoneyShort(totals.totalValue),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? _errorState(error)
                    : _resultsList(parcels, orders),
          ),
        ],
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected ? AppColors.textOnPrimary : AppColors.navyPrimary,
            ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.navyPrimary,
      labelStyle: TextStyle(
        color: selected ? AppColors.textOnPrimary : AppColors.navyPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: AppColors.surfaceWhite,
      side: BorderSide(
        color: selected ? AppColors.navyPrimary : AppColors.borderLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.navyPrimary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Could not load history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(parcelsStreamProvider);
                ref.invalidate(allOrderRequestsStreamProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsList(
    List<ParcelModel> parcels,
    List<OrderRequestModel> orders,
  ) {
    if (parcels.isEmpty && orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                _query.isEmpty && _dateRange == null
                    ? 'No parcel or order history yet'
                    : 'No results match your search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_query.isNotEmpty || _dateRange != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Try a different keyword or clear the date filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final entries = <_ResultEntry>[
      if (parcels.isNotEmpty) _HeaderEntry('Parcels', parcels.length),
      ...parcels.map(_ParcelEntry.new),
      if (orders.isNotEmpty) _HeaderEntry('Orders', orders.length),
      ...orders.map(_OrderEntry.new),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is _HeaderEntry) {
          return _sectionHeader(entry.title, entry.count);
        }
        if (entry is _ParcelEntry) {
          return _parcelCard(entry.parcel);
        }
        return _orderCard((entry as _OrderEntry).order);
      },
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _parcelCard(ParcelModel parcel) {
    final statusColor = _parcelStatusColor(parcel.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderLight),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/parcels/${parcel.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parcel.trackingNumber,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                    _statusChip(parcel.status, statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parcel.customerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatMoneyShort(parcel.amount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${parcel.platform} • ${parcel.courier} • '
                  '${_dayFormat.format(parcel.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(OrderRequestModel order) {
    final statusColor = _orderStatusColor(order.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderLight),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showOrderDetails(order),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.plateText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                    _statusChip(
                      order.status.replaceAll('_', ' '),
                      statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.customerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(order.price),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.plateStyle} • '
                  '${_dayFormat.format(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _parcelStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'delivered':
        return AppColors.statusDelivered;
      case 'in transit':
        return AppColors.statusInTransit;
      case 'dispatched':
        return AppColors.statusDispatched;
      case 'returned':
        return AppColors.statusReturned;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.statusPending;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
      case 'in_production':
        return AppColors.statusProcessing;
      case 'dispatched':
        return AppColors.statusDispatched;
      case 'delivered':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.statusPending;
    }
  }

  void _showOrderDetails(OrderRequestModel order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order ${order.plateText}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyPrimary,
                          ),
                        ),
                      ),
                      _statusChip(
                        order.status.replaceAll('_', ' '),
                        _orderStatusColor(order.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow('Customer', order.customerName),
                  _detailRow('Phone', order.customerPhone),
                  _detailRow('Style', order.plateStyle),
                  _detailRow('Address', order.deliveryAddress),
                  _detailRow('Estimated price', formatMoney(order.price)),
                  _detailRow('Created', _dayFormat.format(order.createdAt)),
                  if (order.notes.trim().isNotEmpty)
                    _detailRow('Notes', order.notes),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _ResultEntry {
  const _ResultEntry();
}

class _HeaderEntry extends _ResultEntry {
  const _HeaderEntry(this.title, this.count);
  final String title;
  final int count;
}

class _ParcelEntry extends _ResultEntry {
  const _ParcelEntry(this.parcel);
  final ParcelModel parcel;
}

class _OrderEntry extends _ResultEntry {
  const _OrderEntry(this.order);
  final OrderRequestModel order;
}
