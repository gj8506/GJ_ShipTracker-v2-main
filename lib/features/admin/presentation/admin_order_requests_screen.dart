import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/order_pricing.dart';
import '../../auth/presentation/auth_providers.dart';
import 'order_admin_providers.dart';

/// Admin-only list of submitted plate orders with a final-price override.
///
/// Customers submit an estimate with their request; this screen lets the owner
/// confirm or adjust the amount that appears on the customer's order details.
class AdminOrderRequestsScreen extends ConsumerStatefulWidget {
  const AdminOrderRequestsScreen({super.key});

  @override
  ConsumerState<AdminOrderRequestsScreen> createState() =>
      _AdminOrderRequestsScreenState();
}

class _AdminOrderRequestsScreenState
    extends ConsumerState<AdminOrderRequestsScreen> {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  static const List<String> _statusFilters = [
    'All',
    'PENDING',
    'APPROVED',
    'IN_PRODUCTION',
    'DISPATCHED',
    'DELIVERED',
    'CANCELLED',
  ];

  final _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrderRequestsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Order Requests',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh orders',
            onPressed: () => ref.invalidate(adminOrderRequestsStreamProvider),
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
                hintText: 'Search plate, customer, phone, tracking...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
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
                for (final filter in _statusFilters) ...[
                  _statusChip(filter),
                  if (filter != _statusFilters.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _errorState(error),
              data: (orders) {
                final visible = orders.where(_isVisible).toList();
                if (visible.isEmpty) {
                  return _emptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _orderCard(visible[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String filter) {
    final selected = _statusFilter == filter;
    final label = filter == 'All'
        ? 'All orders'
        : filter.replaceAll('_', ' ').toLowerCase();

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = filter),
      selectedColor: AppColors.navyPrimary,
      backgroundColor: AppColors.surfaceWhite,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: selected ? AppColors.navyPrimary : AppColors.borderLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  bool _isVisible(Map<String, dynamic> order) {
    final status = _value(order, ['status']).toLowerCase();
    if (_statusFilter != 'All' && status != _statusFilter.toLowerCase()) {
      return false;
    }

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;

    return [
      'plateNumber',
      'plateText',
      'plateSpecs',
      'plateStyle',
      'customerName',
      'recipientName',
      'contactNumber',
      'customerPhone',
      'trackingNumber',
      'deliveryAddress',
      'region',
      'brandMake',
    ].any((key) => _value(order, [key]).toLowerCase().contains(query));
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = _value(order, ['status'], fallback: 'PENDING');
    final statusColor = _statusColor(status);
    final price = resolveOrderPrice(order);
    final finalPrice = hasFinalPrice(order);
    final tracking = _value(order, ['trackingNumber']);
    final createdAt = order['createdAt'];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showOrderDetails(order),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: Text(
                    _plateOf(order),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ),
                _chip(
                  status.replaceAll('_', ' '),
                  statusColor,
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _value(order, ['customerName', 'recipientName'],
                        fallback: 'Valued Customer'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    price == null ? 'Pending quote' : formatMoneyShort(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: finalPrice
                          ? AppColors.statusDelivered
                          : AppColors.navyPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _value(order, ['plateStyle'], fallback: 'Custom plate'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (createdAt is DateTime)
                  Text(
                    _dateFormat.format(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  )
                else if (createdAt != null)
                  Text(
                    _dateFormat.format((createdAt as dynamic).toDate()),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            if (tracking.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Track: $tracking',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealDark,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              finalPrice
                  ? 'Final price set — tap to review'
                  : 'Tap to set final price',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: finalPrice
                    ? AppColors.statusDelivered
                    : AppColors.statusPending,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final status = _value(order, ['status'], fallback: 'PENDING');
    final price = resolveOrderPrice(order);
    final finalPrice = hasFinalPrice(order);
    final createdAt = order['createdAt'];
    final date = createdAt is DateTime
        ? _dateFormat.format(createdAt)
        : createdAt == null
            ? '—'
            : _dateFormat.format((createdAt as dynamic).toDate());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order ${_plateOf(order)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                    _chip(
                      status.replaceAll('_', ' '),
                      _statusColor(status),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Customer',
                    _value(order, ['customerName', 'recipientName'])),
                _detailRow(
                    'Phone', _value(order, ['contactNumber', 'customerPhone'])),
                _detailRow('Plate style',
                    _value(order, ['plateStyle'], fallback: '—')),
                _detailRow('Plate specs',
                    _value(order, ['plateSpecs'], fallback: _specsOf(order))),
                _detailRow('Region', _value(order, ['region'], fallback: '—')),
                _detailRow('Brand / make',
                    _value(order, ['brandMake'], fallback: '—')),
                _detailRow('Address',
                    _value(order, ['deliveryAddress'], fallback: '—')),
                _detailRow('Order date', date),
                if (_value(order, ['trackingNumber']).isNotEmpty)
                  _detailRow('Tracking', _value(order, ['trackingNumber'])),
                if (_value(order, ['specialNotes', 'notes']).isNotEmpty)
                  _detailRow('Notes', _value(order, ['specialNotes', 'notes'])),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      finalPrice ? 'Final price' : 'Estimated price',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        price == null ? 'Pending quote' : formatMoney(price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: finalPrice
                              ? AppColors.statusDelivered
                              : AppColors.navyPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_value(order, ['finalPriceUpdatedAt']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Last updated by '
                      '${_value(order, [
                            'finalPriceUpdatedByName'
                          ], fallback: 'admin')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _promptPriceOverride(order);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(
                      finalPrice ? 'Override final price' : 'Set final price',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptPriceOverride(Map<String, dynamic> order) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _PriceOverrideDialog(
          orderId: _value(order, ['id']),
          plate: _plateOf(order),
          customer: _value(order, ['customerName'], fallback: 'Customer'),
          initialPrice: resolveOrderPrice(order),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Final price updated for this order.')),
        );
    }
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Could not load orders',
              style: TextStyle(
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(adminOrderRequestsStreamProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 60, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty && _statusFilter == 'All'
                  ? 'No plate orders have been submitted yet'
                  : 'No orders match your filters',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final shown = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              shown,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
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

  Color _statusColor(String status) {
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

  String _plateOf(Map<String, dynamic> order) =>
      _value(order, ['plateNumber', 'plateText'], fallback: 'N/A');

  String _specsOf(Map<String, dynamic> order) {
    final region = _value(order, ['region']);
    final make = _value(order, ['brandMake']);
    if (region.isEmpty && make.isEmpty) return '—';
    return [region, make].where((part) => part.isNotEmpty).join(' • ');
  }

  String _value(
    Map<String, dynamic> order,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = order[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null && value is! String) return '$value';
    }
    return fallback;
  }
}

/// Owns the price field so its controller outlives the dialog's close
/// animation. Disposing a controller while the route is still animating out
/// throws "A TextEditingController was used after being disposed".
class _PriceOverrideDialog extends ConsumerStatefulWidget {
  const _PriceOverrideDialog({
    required this.orderId,
    required this.plate,
    required this.customer,
    required this.initialPrice,
  });

  final String orderId;
  final String plate;
  final String customer;
  final double? initialPrice;

  @override
  ConsumerState<_PriceOverrideDialog> createState() =>
      _PriceOverrideDialogState();
}

class _PriceOverrideDialogState extends ConsumerState<_PriceOverrideDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPrice == null
        ? ''
        : widget.initialPrice!.toStringAsFixed(2),
  );

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = validatePriceOverride(_controller.text);
    if (!parsed.isValid) {
      setState(() => _error = parsed.error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // The dialog can be opened before the profile stream has delivered its
    // first value; awaiting the future keeps the audit fields accurate.
    var adminUid = '';
    var adminName = 'Admin';
    try {
      final profile = await ref.read(userProfileProvider.future);
      if (!mounted) return;
      adminUid = profile?.uid ?? adminUid;
      adminName = profile?.displayName ?? adminName;
    } catch (_) {
      // Saving the price is more important than the audit name; the rules
      // still verify that the writer is an admin.
    }

    try {
      await ref.read(orderAdminRepositoryProvider).updateFinalPrice(
            orderId: widget.orderId,
            amount: parsed.value!,
            adminUid: adminUid,
            adminName: adminName,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the price. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Override final price'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.plate} • ${widget.customer}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              readOnly: _saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Hard cap: 9 whole digits, 2 decimals, no scientific notation.
              inputFormatters: moneyInputFormatters,
              decoration: InputDecoration(
                labelText: 'Final price (₱)',
                prefixText: '₱ ',
                helperText: 'Up to ₱999,999,999.00',
                errorText: _error,
              ),
              onSubmitted: (_) {
                if (!_saving) _save();
              },
            ),
            const SizedBox(height: 10),
            Text(
              'The customer sees this amount in My Orders. The original '
              'estimate is kept for records.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save price'),
        ),
      ],
    );
  }
}
