import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import 'customer_portal_providers.dart';

class CustomerHomeScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToSupport;
  final VoidCallback? onNavigateToRequest;

  const CustomerHomeScreen({
    super.key,
    this.onNavigateToOrders,
    this.onNavigateToSupport,
    this.onNavigateToRequest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final ordersAsync = ref.watch(customerOrdersStreamProvider);
    final activeCount = ref.watch(customerActiveOrdersCountProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_outlined,
                color: AppColors.navyPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userProfile?.displayName ?? 'Customer Portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const Text(
                    'Custom License Plate Service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.navySecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: AppColors.textSecondary,
            ),
            onPressed: onNavigateToSupport,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Plate Request Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navySecondary, AppColors.navyPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyPrimary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.logoBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'FAST TRACK FABRICATION',
                          style: TextStyle(
                            color: AppColors.navyDark,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Icon(Icons.directions_car_filled,
                          color: Colors.white70, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Order Your Custom Plate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'High-grade embossed aluminum, tamper-resistant hologram, LTO-compliant styling.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceWhite,
                      foregroundColor: AppColors.navyPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onNavigateToRequest,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text(
                      'Start Order Request',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order Status Overview Cards
            const Text(
              'Order Status Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Active Orders',
                    count: '$activeCount',
                    color: AppColors.statusInTransit,
                    bgColor: AppColors.statusInTransitContainer,
                    icon: Icons.hourglass_top_rounded,
                    onTap: onNavigateToOrders,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ordersAsync.maybeWhen(
                    data: (orders) {
                      final delivered = orders.where((o) {
                        final status =
                            (o['status'] as String?)?.toLowerCase() ?? '';
                        return status == 'delivered';
                      }).length;

                      return _buildMetricCard(
                        title: 'Delivered',
                        count: '$delivered',
                        color: AppColors.statusDelivered,
                        bgColor: AppColors.statusDeliveredContainer,
                        icon: Icons.check_circle_outline,
                        onTap: onNavigateToOrders,
                      );
                    },
                    orElse: () => _buildMetricCard(
                      title: 'Delivered',
                      count: '0',
                      color: AppColors.statusDelivered,
                      bgColor: AppColors.statusDeliveredContainer,
                      icon: Icons.check_circle_outline,
                      onTap: onNavigateToOrders,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Orders Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Plate Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: onNavigateToOrders,
                  child: const Text(
                    'View All',
                    style: TextStyle(color: AppColors.tealDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ordersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.statusReturnedContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Unable to load orders: $err',
                  style: const TextStyle(color: AppColors.statusReturned),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Plate Orders Yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Submit your first custom plate order to track status and dispatch here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final recentOrders = orders.take(3).toList();
                return Column(
                  children: recentOrders.map((order) {
                    final orderStatus =
                        order['status']?.toString() ?? 'PENDING';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.borderStrong, width: 1.5),
                            ),
                            child: Text(
                              order['plateNumber']?.toString() ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order['plateStyle']?.toString() ??
                                      'Custom Plate',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text(
                                  order['deliveryAddress']?.toString() ??
                                      'No Address',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(orderStatus)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              orderStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(orderStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required Color color,
    required Color bgColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
