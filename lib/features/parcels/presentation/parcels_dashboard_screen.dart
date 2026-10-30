import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/parcel_model.dart';
import 'parcel_providers.dart';

class ParcelsDashboardScreen extends ConsumerWidget {
  const ParcelsDashboardScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusDispatched:
        return AppColors.statusDispatched;
      case AppConstants.statusInTransit:
        return AppColors.statusInTransit;
      case AppConstants.statusDelivered:
        return AppColors.statusDelivered;
      case AppConstants.statusReturned:
        return AppColors.statusReturned;
      default:
        return AppColors.statusPending;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allParcelsAsync = ref.watch(parcelsStreamProvider);
    final filteredParcels = ref.watch(filteredParcelsProvider);
    final selectedPlatform = ref.watch(selectedPlatformFilterProvider);

    // Compute live parcel counts per platform
    final allParcels = allParcelsAsync.value ?? [];
    final shopeeCount = allParcels
        .where((p) => p.platform == AppConstants.platformShopee)
        .length;
    final lazadaCount = allParcels
        .where((p) => p.platform == AppConstants.platformLazada)
        .length;
    final tikTokCount = allParcels
        .where((p) => p.platform == AppConstants.platformTikTok)
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Parcels Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.go('/dispatch'),
            tooltip: 'Dispatch New Parcel',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Live Platform Summary Header Cards
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Shopee',
                    count: '$shopeeCount pkgs',
                    titleColor: AppColors.shopeeOrange,
                    bgColor: AppColors.shopeeContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Lazada',
                    count: '$lazadaCount pkgs',
                    titleColor: AppColors.lazadaBlue,
                    bgColor: AppColors.lazadaContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'TikTok',
                    count: '$tikTokCount pkgs',
                    titleColor: AppColors.tikTokBlack,
                    bgColor: AppColors.tikTokContainer,
                  ),
                ),
              ],
            ),
          ),

          // 2. Multi-field Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search tracking number, customer, courier...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Platform Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip(ref, 'All', selectedPlatform),
                const SizedBox(width: 8),
                _buildFilterChip(
                    ref, AppConstants.platformShopee, selectedPlatform),
                const SizedBox(width: 8),
                _buildFilterChip(
                    ref, AppConstants.platformLazada, selectedPlatform),
                const SizedBox(width: 8),
                _buildFilterChip(
                    ref, AppConstants.platformTikTok, selectedPlatform),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Parcel List Area
          Expanded(
            child: allParcelsAsync.when(
              data: (_) {
                if (filteredParcels.isEmpty) {
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
                          'No parcels match your filters',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  itemCount: filteredParcels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final parcel = filteredParcels[index];
                    return _buildParcelCard(context, parcel);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading parcels: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String count,
    required Color titleColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: titleColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      WidgetRef ref, String label, String? currentSelected) {
    final isSelected = (label == 'All' && currentSelected == null) ||
        (currentSelected == label);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(selectedPlatformFilterProvider.notifier).state =
            label == 'All' ? null : label;
      },
      selectedColor: AppColors.navyPrimary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.textOnPrimary : AppColors.navyPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: AppColors.surfaceWhite,
      side: BorderSide(
        color: isSelected ? AppColors.navyPrimary : AppColors.borderLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildParcelCard(BuildContext context, ParcelModel parcel) {
    final statusColor = _getStatusColor(parcel.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/parcels/${parcel.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    parcel.trackingNumber,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      parcel.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    parcel.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '₱${parcel.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${parcel.platform} • ${parcel.courier}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
