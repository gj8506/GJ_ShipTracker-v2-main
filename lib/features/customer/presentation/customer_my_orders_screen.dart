import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_portal_providers.dart'; // Imports the secure, shared stream

class CustomerMyOrdersScreen extends ConsumerStatefulWidget {
  const CustomerMyOrdersScreen({super.key});

  @override
  ConsumerState<CustomerMyOrdersScreen> createState() =>
      _CustomerMyOrdersScreenState();
}

class _CustomerMyOrdersScreenState
    extends ConsumerState<CustomerMyOrdersScreen> {
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
                  style: const TextStyle(color: AppColors.errorRed),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
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
    final status = (order['status'] as String?) ?? 'PENDING';
    final statusColor = _getStatusColor(status);
    final finalAmount = order['finalAmount'];
    final tracking = (order['trackingNumber'] as String?) ?? '';

    return InkWell(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppColors.borderStrong, width: 1.5),
                  ),
                  child: Text(
                    order['plateNumber'] ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order['plateStyle'] ?? 'Custom Plate',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order['deliveryAddress'] ?? 'No Address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Date: ${_formatDate(order['createdAt'] as Timestamp?)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (tracking.isNotEmpty)
                  Text(
                    'Track: $tracking',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                    ),
                  )
                else
                  Text(
                    finalAmount != null
                        ? '₱${finalAmount.toStringAsFixed(2)}'
                        : 'Pending Quote',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: finalAmount != null
                          ? AppColors.navyPrimary
                          : AppColors.statusPending,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    final tracking = (order['trackingNumber'] as String?) ?? '';
    final notes = (order['specialNotes'] as String?) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              _buildDetailRow('Plate Text:', order['plateNumber'] ?? 'N/A'),
              _buildDetailRow('Style:', order['plateStyle'] ?? 'N/A'),
              _buildDetailRow('Specs:',
                  '${order['region'] ?? ''} - ${order['brandMake'] ?? ''}'),
              _buildDetailRow('Status:',
                  (order['status'] as String?)?.toUpperCase() ?? 'PENDING'),
              _buildDetailRow('Recipient:', order['customerName'] ?? 'N/A'),
              _buildDetailRow('Phone:', order['contactNumber'] ?? 'N/A'),
              _buildDetailRow(
                  'Delivery Address:', order['deliveryAddress'] ?? 'N/A'),
              if (tracking.isNotEmpty)
                _buildDetailRow('Dispatch Tracking:', tracking),
              if (notes.isNotEmpty) _buildDetailRow('Special Notes:', notes),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? dt) {
    if (dt == null) return 'Unknown Date';
    final date = dt.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
