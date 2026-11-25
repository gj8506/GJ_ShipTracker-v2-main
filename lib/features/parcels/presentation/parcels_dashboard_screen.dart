import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../domain/parcel_model.dart';
import 'parcel_providers.dart';

class ParcelsDashboardScreen extends ConsumerStatefulWidget {
  const ParcelsDashboardScreen({super.key});

  @override
  ConsumerState<ParcelsDashboardScreen> createState() =>
      _ParcelsDashboardScreenState();
}

class _ParcelsDashboardScreenState
    extends ConsumerState<ParcelsDashboardScreen> {
  /// The dashboard shows ten parcels per page, as requested.
  static const int _pageSize = 10;

  /// Zero-based index of the parcel page currently shown.
  int _page = 0;

  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _resetPage() {
    if (_page != 0) setState(() => _page = 0);
  }

  void _goToPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    if (_listController.hasClients) {
      _listController.jumpTo(0);
    }
  }

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

  Color _getStatusContainerColor(String status) {
    switch (status) {
      case AppConstants.statusDispatched:
        return AppColors.statusDispatchedContainer;
      case AppConstants.statusInTransit:
        return AppColors.statusInTransitContainer;
      case AppConstants.statusDelivered:
        return AppColors.statusDeliveredContainer;
      case AppConstants.statusReturned:
        return AppColors.statusReturnedContainer;
      default:
        return AppColors.statusPendingContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        toolbarHeight: 64,
        title: const Text(
          'Parcels Dashboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: () => context.push('/search-summary'),
            tooltip: 'Search Summary',
          ),
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
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).state = val;
                // A new search always starts from the first page so the user
                // never lands on an empty, out-of-range page.
                _resetPage();
              },
              decoration: InputDecoration(
                hintText: 'Search tracking number, customer, courier...',
                prefixIcon: const Icon(Icons.search),
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

          // 4. Parcel List Area — slice AFTER search + platform filters run.
          Expanded(
            child: allParcelsAsync.when(
              data: (_) {
                if (filteredParcels.isEmpty) {
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

                final pageCount = PaginationBar.pageCountFor(
                  filteredParcels.length,
                  _pageSize,
                );
                final page = PaginationBar.clampPage(
                  _page,
                  filteredParcels.length,
                  _pageSize,
                );
                final visibleParcels = PaginationBar.pageSlice(
                  filteredParcels,
                  page,
                  _pageSize,
                );

                final hasPagination = pageCount > 1;

                // The footer is the last row of the same scrollable list, so
                // all ten parcel cards stay visible above it and the controls
                // never pin over a card.
                return ListView.separated(
                  controller: _listController,
                  padding: EdgeInsets.fromLTRB(
                    16.0,
                    8.0,
                    16.0,
                    hasPagination ? 8.0 : 84.0,
                  ),
                  itemCount: visibleParcels.length + (hasPagination ? 1 : 0),
                  separatorBuilder: (_, index) => SizedBox(
                    height: index == visibleParcels.length - 1 ? 24 : 10,
                  ),
                  itemBuilder: (context, index) {
                    if (hasPagination && index == visibleParcels.length) {
                      return Padding(
                        // Extra bottom room keeps the row clear of the
                        // floating chatbot button when scrolled to the end.
                        padding: const EdgeInsets.only(bottom: 88),
                        child: PaginationBar(
                          page: page,
                          pageCount: pageCount,
                          itemCount: filteredParcels.length,
                          pageSize: _pageSize,
                          itemLabel: 'parcels',
                          onPageChanged: _goToPage,
                        ),
                      );
                    }
                    return _buildParcelCard(context, visibleParcels[index]);
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
                    style: TextStyle(color: AppColors.errorRed),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
        _resetPage();
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
    final statusContainer = _getStatusContainerColor(parcel.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderLight),
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
                children: [
                  Expanded(
                    child: Text(
                      parcel.trackingNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Standardised status pill: soft container + strong label.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      parcel.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  Expanded(
                    child: Text(
                      parcel.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      formatMoneyShort(parcel.amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${parcel.platform} • ${parcel.courier}',
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
    );
  }
}
