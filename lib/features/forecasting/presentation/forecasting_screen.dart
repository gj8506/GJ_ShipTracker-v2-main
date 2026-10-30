import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/forecast_models.dart';
import 'forecasting_provider.dart';

class ForecastingScreen extends ConsumerStatefulWidget {
  const ForecastingScreen({super.key});

  @override
  ConsumerState<ForecastingScreen> createState() => _ForecastingScreenState();
}

class _ForecastingScreenState extends ConsumerState<ForecastingScreen> {
  bool _isGeneratingSimulation = false;

  Future<void> _inject14MonthData() async {
    setState(() => _isGeneratingSimulation = true);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final random = Random();
      final platforms = [
        AppConstants.platformShopee,
        AppConstants.platformLazada,
        'TikTok',
        'Direct',
      ];
      final couriers = ['J&T Express', 'SPX Express', 'Flash Express'];

      int idCounter = 1;
      for (int m = 13; m >= 0; m--) {
        final monthDate = DateTime(now.year, now.month - m, 1);
        final count = 5 + random.nextInt(3);
        final growthFactor = 1.0 + ((13 - m) * 0.05);

        for (int p = 0; p < count; p++) {
          final day = min(28, (p * 5) + 2);
          final date = DateTime(monthDate.year, monthDate.month, day, 10, 30);
          final id =
              'SMPL-${monthDate.year}${monthDate.month.toString().padLeft(2, '0')}-$idCounter';
          final baseAmt = (random.nextInt(20) + 12) * 100.0;
          final amount =
              double.parse((baseAmt * growthFactor).toStringAsFixed(2));

          final ref = FirebaseFirestore.instance
              .collection(AppConstants.collectionParcels)
              .doc(id);
          batch.set(ref, {
            'trackingNumber': id,
            'platform': platforms[p % platforms.length],
            'courier': couriers[random.nextInt(couriers.length)],
            'customerName': 'Store Client $idCounter',
            'amount': amount,
            'totalPrice': amount,
            'status': AppConstants.statusDelivered,
            'isSample': true,
            'createdAt': Timestamp.fromDate(date),
            'dispatchedAt': Timestamp.fromDate(date),
            'dateShipped': Timestamp.fromDate(date),
          });
          idCounter++;
        }
      }

      await batch.commit();
      ref.invalidate(historicalSalesProvider);

      if (mounted) {
        scaffold.showSnackBar(
          const SnackBar(
            content: Text(
                'Injected 14 months of historical shipments! All forecast horizons unlocked.'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.statusReturned),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSimulation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedHorizon = ref.watch(selectedHorizonProvider);
    final selectedPlatform = ref.watch(selectedPlatformProvider);
    final forecastResult = ref.watch(forecastResultProvider);
    final historyAsync = ref.watch(historicalSalesProvider);
    final currencyFmt =
        NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Predictive Sales Forecasting'),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historicalSalesProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (_) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Horizon & Channel Selectors
                _buildFilterCard(selectedHorizon, selectedPlatform),
                const SizedBox(height: 14),

                // 2. Either Render Insufficient Warning OR Full Forecast
                if (!forecastResult.hasSufficientData) ...[
                  _buildInsufficientDataCard(forecastResult, selectedHorizon),
                ] else ...[
                  _buildTotalProjections(
                      forecastResult, selectedHorizon, currencyFmt),
                  const SizedBox(height: 16),
                  _buildMonthlyBreakdown(forecastResult, currencyFmt),
                  const SizedBox(height: 16),
                  _buildInsightCard(forecastResult),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterCard(
      ForecastHorizon activeHorizon, String activePlatform) {
    const platforms = ['All', 'Shopee', 'Lazada', 'TikTok'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forecast Horizon',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.navyMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: ForecastHorizon.values.map((horizon) {
              final isSelected = horizon == activeHorizon;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => ref
                        .read(selectedHorizonProvider.notifier)
                        .state = horizon,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.navyPrimary
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navyPrimary
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            horizon.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sales Channel',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.navyMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: platforms.map((plat) {
              final isSelected = plat == activePlatform;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => ref
                        .read(selectedPlatformProvider.notifier)
                        .state = plat,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.navyPrimary
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navyPrimary
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            plat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataCard(
      ForecastResult result, ForecastHorizon currentHorizon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.statusPending, size: 22),
              SizedBox(width: 8),
              Text(
                'Insufficient Historical Shipments',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningDeep),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.insightSummary,
            style: const TextStyle(
                fontSize: 13, color: AppColors.warningDeepest, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (currentHorizon != ForecastHorizon.oneMonth)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningStrong,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ref.read(selectedHorizonProvider.notifier).state =
                      ForecastHorizon.oneMonth;
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Switch to 1-Month Forecast',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyPrimary,
                side: const BorderSide(color: AppColors.navyPrimary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isGeneratingSimulation ? null : _inject14MonthData,
              icon: _isGeneratingSimulation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_graph_rounded, size: 18),
              label: const Text('Simulate 14-Month History (Instant Fix)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalProjections(
    ForecastResult result,
    ForecastHorizon horizon,
    NumberFormat currencyFmt,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.tealContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_up_rounded,
                          size: 16, color: AppColors.navyPrimary),
                    ),
                    const SizedBox(width: 8),
                    const Text('Projected Sales',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  currencyFmt.format(result.totalProjectedRevenue),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${horizon.fullTitle} Total',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.statusDeliveredContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          size: 16, color: AppColors.statusDelivered),
                    ),
                    const SizedBox(width: 8),
                    const Text('Est. Volume',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${NumberFormat('#,##0').format(result.totalProjectedParcels)} pkgs',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.growthRatePercent >= 0 ? '+' : ''}${result.growthRatePercent.toStringAsFixed(1)}% trajectory',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: result.growthRatePercent >= 0
                        ? AppColors.statusDelivered
                        : AppColors.statusReturned,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyBreakdown(
      ForecastResult result, NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Projections',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.confidence.title,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result.forecastPoints.map((pt) {
            final monthName =
                DateFormat('MMMM yyyy').format(DateTime(pt.year, pt.month));
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceMuted),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.navySecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Estimated: ${pt.projectedParcels} dispatched orders',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    currencyFmt.format(pt.projectedRevenue),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.navyPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightCard(ForecastResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: AppColors.navyPrimary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operational Forecast Strategy',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  result.insightSummary,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.tealDark, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
