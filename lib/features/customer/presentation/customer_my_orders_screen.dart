import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/order_pricing.dart';
import 'customer_portal_providers.dart'; // Imports the secure, shared stream

class CustomerMyOrdersScreen extends ConsumerStatefulWidget {
  const CustomerMyOrdersScreen({super.key});

  @override
  ConsumerState<CustomerMyOrdersScreen> createState() =>
      _CustomerMyOrdersScreenState();
}

class _CustomerMyOrdersScreenState
    extends ConsumerState<CustomerMyOrdersScreen> {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'pending',
    'in_production',
    'dispatched',
    'delivered'
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'My Custom Plate Orders',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter == 'All'
                            ? 'All Orders'
                            : filter.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      selectedColor: AppColors.navyPrimary,
                      backgroundColor: AppColors.surfaceMuted,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error loading orders: $err',
                  style: TextStyle(color: AppColors.errorRed),
                ),
              ),
              data: (orders) {
                final filtered = orders.where((order) {
                  if (_selectedFilter == 'All') return true;
                  final status =
                      (order['status'] as String?)?.toLowerCase() ?? '';
                  return status == _selectedFilter.toLowerCase();
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders match this filter',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildOrderCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = _value(order, ['status'], fallback: 'PENDING');
    final statusColor = _getStatusColor(status);
    final price = resolveOrderPrice(order);
    final hasFinal = hasFinalPrice(order);
    final tracking = _value(order, ['trackingNumber']);
    final specs = _plateSpecs(order);
    final plate = _value(order, ['plateNumber', 'plateText'], fallback: 'N/A');

    return Semantics(
      button: true,
      label: 'View order details for plate $plate',
      child: InkWell(
        onTap: () => _showOrderDetailSheet(order),
        borderRadius: BorderRadius.circular(12),
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.borderStrong, width: 1.5),
                        ),
                        child: Text(
                          plate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(status, statusColor),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _value(order, ['plateStyle'], fallback: 'Custom Plate'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  specs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _value(order, ['deliveryAddress'],
                          fallback: 'No Address'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (tracking.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: AppColors.tealDark,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Track: $tracking',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ordered ${_formatDate(order['createdAt'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    price == null
                        ? 'Pending quote'
                        : '${hasFinal ? 'Final' : 'Est.'} '
                            '${_moneyFormat.format(price)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: hasFinal
                          ? AppColors.statusDelivered
                          : AppColors.navyPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    final plate = _value(order, ['plateNumber', 'plateText'], fallback: 'N/A');
    final status = _value(order, ['status'], fallback: 'PENDING');
    final statusColor = _getStatusColor(status);
    final price = resolveOrderPrice(order);
    final hasFinal = hasFinalPrice(order);
    final tracking = _value(order, ['trackingNumber']);
    final notes = _value(order, ['specialNotes', 'notes']);
    final orderId = _value(order, ['id']);
    final estimate = order['estimatedPrice'];
    final showOriginalEstimate = hasFinal &&
        estimate is num &&
        (price == null || (estimate.toDouble() - price).abs() > 0.004);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plate,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(status, statusColor),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close order details',
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasFinal
                        ? AppColors.statusDelivered.withValues(alpha: 0.10)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasFinal
                          ? AppColors.statusDelivered.withValues(alpha: 0.4)
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasFinal ? 'FINAL PRICE' : 'ESTIMATED PRICE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              price == null
                                  ? 'Pending quote'
                                  : _moneyFormat.format(price),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: hasFinal
                                    ? AppColors.statusDelivered
                                    : AppColors.navyPrimary,
                              ),
                            ),
                            if (showOriginalEstimate) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Original estimate '
                                '${_moneyFormat.format(estimate.toDouble())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 34,
                        color: hasFinal
                            ? AppColors.statusDelivered
                            : AppColors.navyPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Plate specifications'),
                _buildDetailRow('Plate text', plate),
                _buildDetailRow(
                  'Style',
                  _value(order, ['plateStyle'], fallback: 'N/A'),
                ),
                _buildDetailRow(
                  'Specs',
                  _plateSpecs(order, fallback: 'N/A'),
                ),
                _buildDetailRow(
                  'Region',
                  _value(order, ['region'], fallback: 'N/A'),
                ),
                _buildDetailRow(
                  'Brand / make',
                  _value(order, ['brandMake'], fallback: 'N/A'),
                ),
                const SizedBox(height: 8),
                _sectionTitle('Order status'),
                _buildDetailRow('Status', status.replaceAll('_', ' ')),
                if (tracking.isNotEmpty)
                  _buildDetailRow('Tracking number', tracking),
                const SizedBox(height: 8),
                _sectionTitle('Delivery details'),
                _buildDetailRow(
                  'Recipient',
                  _value(order, ['customerName', 'recipientName'],
                      fallback: 'N/A'),
                ),
                _buildDetailRow(
                  'Phone',
                  _value(order, ['contactNumber', 'customerPhone'],
                      fallback: 'N/A'),
                ),
                _buildDetailRow(
                  'Delivery address',
                  _value(order, ['deliveryAddress'], fallback: 'N/A'),
                ),
                _buildDetailRow('Order date', _formatDate(order['createdAt'])),
                if (orderId.isNotEmpty)
                  _buildDetailRow('Order reference', orderId),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionTitle('Notes'),
                  _buildDetailRow('Special notes', notes),
                ],
                const SizedBox(height: 8),
                Text(
                  hasFinal
                      ? 'This final price was set by GJ and Asher after reviewing '
                          'your plate request.'
                      : 'This is the estimated price for your selected plate. '
                          'The final price is confirmed after review.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final shown = value.trim().isEmpty ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Object? value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }
    if (date == null) return 'Date pending';
    return _dateFormat.format(date);
  }

  String _plateSpecs(Map<String, dynamic> order, {String fallback = ''}) {
    final specs = _value(order, ['plateSpecs']);
    if (specs.isNotEmpty) return specs;

    final region = _value(order, ['region']);
    final make = _value(order, ['brandMake']);
    final parts = [region, make].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? fallback : parts.join(' • ');
  }

  String _value(
    Map<String, dynamic> order,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = order[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'approved':
      case 'in_production':
        return AppColors.statusProcessing;
      case 'dispatched':
        return AppColors.statusReplacementDispatched;
      case 'delivered':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusReturned;
      default:
        return AppColors.statusCancelled;
    }
  }
}
