import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../forecasting/presentation/forecasting_screen.dart';

// -------------------------------------------------------------
// FILTER STATE ENUM & PROVIDER
// -------------------------------------------------------------
enum AnalyticsTimeRange {
  oneWeek('7D', 'Past 7 Days', 7),
  oneMonth('1M', 'Past 30 Days', 30),
  threeMonths('3M', 'Past 3 Months', 90),
  sixMonths('6M', 'Past 6 Months', 180),
  oneYear('1Y', 'Past Year', 365);

  final String label;
  final String title;
  final int days;
  const AnalyticsTimeRange(this.label, this.title, this.days);
}

final analyticsTimeRangeProvider =
    StateProvider<AnalyticsTimeRange>((ref) => AnalyticsTimeRange.oneYear);

// -------------------------------------------------------------
// AUTH STATE PROVIDER
// -------------------------------------------------------------
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// -------------------------------------------------------------
// REAL-TIME STREAM PROVIDERS (AUTH PROTECTED & NO PERMISSION CRASHES)
// -------------------------------------------------------------
final allParcelsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;

  // If user is not yet fully authenticated, emit empty list immediately
  if (user == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  return FirebaseFirestore.instance
      .collection(AppConstants.collectionParcels)
      .snapshots()
      .map((snap) =>
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList())
      .handleError((error) {
    debugPrint('⚠️ [ParcelsStream] Silently caught transient error: $error');
    return <Map<String, dynamic>>[];
  });
});

final allReturnsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;

  if (user == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  return FirebaseFirestore.instance
      .collection(AppConstants.collectionReturns)
      .snapshots()
      .map((snap) =>
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList())
      .handleError((error) {
    debugPrint('⚠️ [ReturnsStream] Silently caught transient error: $error');
    return <Map<String, dynamic>>[];
  });
});

// -------------------------------------------------------------
// MAIN ANALYTICS SCREEN
// -------------------------------------------------------------
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _isProcessingSample = false;
  int _touchedBarIndex = -1;

  // -----------------------------------------------------------
  // SAMPLE DATA ENGINE (14 MONTHS: POPULATES ANALYTICS & FORECASTING)
  // -----------------------------------------------------------
  Future<void> _generateSampleData() async {
    setState(() => _isProcessingSample = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final random = Random();

      final platforms = [
        AppConstants.platformShopee,
        AppConstants.platformLazada,
        'TikTok',
        'Direct / Walk-in',
      ];
      final couriers = ['J&T Express', 'SPX Express', 'Flash Express'];
      final reasons = [
        'Customer Refusal',
        'Damaged during transit',
        'Wrong item / size',
        'Incomplete accessories',
      ];

      int clientCounter = 1;

      for (int monthOffset = 13; monthOffset >= 0; monthOffset--) {
        final monthDate = DateTime(now.year, now.month - monthOffset, 1);
        final parcelsThisMonth = 4 + random.nextInt(3);
        final growthFactor = 1.0 + ((13 - monthOffset) * 0.05);

        for (int p = 0; p < parcelsThisMonth; p++) {
          final dayInMonth = min(28, (p * 5) + random.nextInt(3) + 1);
          final date = DateTime(
            monthDate.year,
            monthDate.month,
            dayInMonth,
            10 + random.nextInt(8),
            random.nextInt(60),
          );

          final sampleId =
              'SMPL-${monthDate.year}${monthDate.month.toString().padLeft(2, '0')}-${1000 + clientCounter}';
          final platform = platforms[p % platforms.length];
          final courier = couriers[random.nextInt(couriers.length)];

          final baseAmount = (random.nextInt(20) + 10) * 100.0;
          final amount =
              double.parse((baseAmount * growthFactor).toStringAsFixed(2));

          final isReturned = (p == 0 && monthOffset % 2 == 0);

          final parcelRef = FirebaseFirestore.instance
              .collection(AppConstants.collectionParcels)
              .doc(sampleId);

          batch.set(parcelRef, {
            'trackingNumber': sampleId,
            'platform': platform,
            'courier': courier,
            'customerName': 'Client ${100 + clientCounter}',
            'contactNumber': '0917${1000000 + random.nextInt(8999999)}',
            'amount': amount,
            'totalPrice': amount,
            'status': isReturned
                ? AppConstants.statusReturned
                : AppConstants.statusDelivered,
            'isSample': true,
            'createdAt': Timestamp.fromDate(date),
            'dispatchedAt': Timestamp.fromDate(date),
            'dateShipped': Timestamp.fromDate(date),
          });

          if (isReturned) {
            final returnRef = FirebaseFirestore.instance
                .collection(AppConstants.collectionReturns)
                .doc(sampleId);

            batch.set(returnRef, {
              'trackingNumber': sampleId,
              'customerName': 'Client ${100 + clientCounter}',
              'platform': platform,
              'courier': courier,
              'amount': amount,
              'reason': reasons[random.nextInt(reasons.length)],
              'status': 'Under Inspection',
              'isSample': true,
              'reportedAt': Timestamp.fromDate(date),
              'createdAt': Timestamp.fromDate(date),
            });
          }

          clientCounter++;
        }
      }

      await batch.commit();

      ref.invalidate(allParcelsStreamProvider);
      ref.invalidate(allReturnsStreamProvider);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Sample data generated! Visual Analytics & Forecasting populated.'),
            backgroundColor: AppColors.statusDelivered,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to generate sample data: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingSample = false);
    }
  }

  Future<void> _deleteSampleData() async {
    setState(() => _isProcessingSample = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final parcelSampleQuery = await FirebaseFirestore.instance
          .collection(AppConstants.collectionParcels)
          .where('isSample', isEqualTo: true)
          .get();

      for (var doc in parcelSampleQuery.docs) {
        batch.delete(doc.reference);
      }

      final returnSampleQuery = await FirebaseFirestore.instance
          .collection(AppConstants.collectionReturns)
          .where('isSample', isEqualTo: true)
          .get();

      for (var doc in returnSampleQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      ref.invalidate(allParcelsStreamProvider);
      ref.invalidate(allReturnsStreamProvider);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Sample data removed.'),
            backgroundColor: AppColors.statusCancelled,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error clearing samples: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingSample = false);
    }
  }

  DateTime _extractDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  void _openExcelExportModal() {
    debugPrint('🔔 [EXCEL_EXPORT] Opening Excel export bottom sheet');
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AdminExcelExportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRange = ref.watch(analyticsTimeRangeProvider);
    final parcelsAsync = ref.watch(allParcelsStreamProvider);
    final returnsAsync = ref.watch(allReturnsStreamProvider);

    final allParcels = parcelsAsync.value ?? [];
    final allReturns = returnsAsync.value ?? [];
    final isLoading = parcelsAsync.isLoading && allParcels.isEmpty;

    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: selectedRange.days));

    final filteredParcels = allParcels.where((p) {
      final date =
          _extractDate(p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
      return date.isAfter(cutoffDate);
    }).toList();

    final filteredReturns = allReturns.where((r) {
      final date = _extractDate(r['reportedAt'] ?? r['createdAt']);
      return date.isAfter(cutoffDate);
    }).toList();

    double totalSales = 0;
    for (var p in filteredParcels) {
      final amt = p['amount'] ?? p['totalPrice'];
      if (amt is num) {
        totalSales += amt.toDouble();
      } else if (amt is String) {
        totalSales += double.tryParse(amt) ?? 0.0;
      }
    }

    final totalDispatched = filteredParcels.length;
    final totalReturned = filteredReturns.length;
    final returnRate = totalDispatched > 0
        ? ((totalReturned / totalDispatched) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Visual Analytics'),
        actions: [
          IconButton(
            key: const ValueKey('admin_excel_export_button'),
            icon: const Icon(
              Icons.table_chart_rounded,
              color: AppColors.statusDelivered,
              size: 26,
            ),
            tooltip: 'Export Organized Excel',
            onPressed: _openExcelExportModal,
          ),
          IconButton(
            tooltip: 'Sales Forecasting (Admin)',
            icon: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.navyPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ForecastingScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allParcelsStreamProvider);
              ref.invalidate(allReturnsStreamProvider);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allParcelsStreamProvider);
                ref.invalidate(allReturnsStreamProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSampleDataBar(),
                    const SizedBox(height: 12),
                    _buildForecastingBanner(context),
                    const SizedBox(height: 16),
                    _buildTimeRangeSelector(selectedRange),
                    const SizedBox(height: 16),
                    _buildMetricCards(
                      totalSales: totalSales,
                      totalDispatched: totalDispatched,
                      totalReturned: totalReturned,
                      returnRate: returnRate,
                      rangeTitle: selectedRange.title,
                    ),
                    const SizedBox(height: 20),
                    _buildBarGraphCard(
                      parcels: filteredParcels,
                      range: selectedRange,
                    ),
                    const SizedBox(height: 20),
                    _buildPlatformShareCard(filteredParcels),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // -------------------------------------------------------------
  // COMPACT SAMPLE DATA TOOL
  // -------------------------------------------------------------
  Widget _buildSampleDataBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.statusPendingContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report_rounded,
              size: 20, color: AppColors.warningDeep),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sample Data Tool (Syncs\nwith Returns Log)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warningDeepest,
                height: 1.2,
              ),
            ),
          ),
          if (_isProcessingSample)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.warningDeep),
            )
          else ...[
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppColors.navyPrimary,
              ),
              onPressed: _generateSampleData,
              child: const Text('Generate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppColors.statusReturned,
              ),
              onPressed: _deleteSampleData,
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SALES FORECASTING CARD
  // -------------------------------------------------------------
  Widget _buildForecastingBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForecastingScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.navyPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navySecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.tealAccent.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: AppColors.tealSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Sales Forecasting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.statusDelivered.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.statusDelivered
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: AppColors.tealSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '1, 3, 6 & 12-month predictive trends & revenue projections',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TIME RANGE SELECTOR PILLS
  // -------------------------------------------------------------
  Widget _buildTimeRangeSelector(AnalyticsTimeRange activeRange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: AnalyticsTimeRange.values.map((range) {
        final isSelected = range == activeRange;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                ref.read(analyticsTimeRangeProvider.notifier).state = range;
              },
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navyPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.navyPrimary
                        : AppColors.borderLight,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                AppColors.navyPrimary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      range.label,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------
  // METRIC CARDS (2X2 GRID)
  // -------------------------------------------------------------
  Widget _buildMetricCards({
    required double totalSales,
    required int totalDispatched,
    required int totalReturned,
    required String returnRate,
    required String rangeTitle,
  }) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview for $rangeTitle',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navyMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Sales',
                value: currencyFormatter.format(totalSales),
                icon: Icons.payments_outlined,
                color: AppColors.statusDelivered,
                bgColor: AppColors.statusDeliveredContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Dispatched',
                value: '$totalDispatched parcels',
                icon: Icons.local_shipping_outlined,
                color: AppColors.navyPrimary,
                bgColor: AppColors.tealContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Returns',
                value: '$totalReturned tickets',
                icon: Icons.assignment_return_outlined,
                color: AppColors.statusPending,
                bgColor: AppColors.warningSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Return Rate',
                value: '$returnRate%',
                icon: Icons.percent,
                color: AppColors.statusReturned,
                bgColor: AppColors.statusReturnedContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.scrimFaint,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navyPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // REVENUE PERFORMANCE (BAR GRAPH)
  // -------------------------------------------------------------
  Widget _buildBarGraphCard({
    required List<Map<String, dynamic>> parcels,
    required AnalyticsTimeRange range,
  }) {
    final now = DateTime.now();

    final List<String> labels = [];
    final List<double> values = [];

    if (range == AnalyticsTimeRange.threeMonths) {
      for (int i = 2; i >= 0; i--) {
        final targetMonth = DateTime(now.year, now.month - i, 1);
        labels.add(DateFormat('MMM').format(targetMonth));

        double monthRevenue = 0;
        for (var p in parcels) {
          final pDate = _extractDate(
              p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
          if (pDate.year == targetMonth.year &&
              pDate.month == targetMonth.month) {
            final amt = p['amount'] ?? p['totalPrice'];
            if (amt is num) monthRevenue += amt.toDouble();
            if (amt is String) monthRevenue += double.tryParse(amt) ?? 0.0;
          }
        }
        values.add(monthRevenue);
      }
    } else if (range == AnalyticsTimeRange.oneWeek) {
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        labels.add(DateFormat('E').format(day));

        double dayRev = 0;
        for (var p in parcels) {
          final pDate = _extractDate(
              p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
          if (pDate.year == day.year &&
              pDate.month == day.month &&
              pDate.day == day.day) {
            final amt = p['amount'] ?? p['totalPrice'];
            if (amt is num) dayRev += amt.toDouble();
            if (amt is String) dayRev += double.tryParse(amt) ?? 0.0;
          }
        }
        values.add(dayRev);
      }
    } else if (range == AnalyticsTimeRange.oneMonth) {
      for (int w = 3; w >= 0; w--) {
        labels.add('Wk ${4 - w}');
        final start = now.subtract(Duration(days: (w + 1) * 7));
        final end = now.subtract(Duration(days: w * 7));

        double weekRev = 0;
        for (var p in parcels) {
          final pDate = _extractDate(
              p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
          if (pDate.isAfter(start) && pDate.isBefore(end)) {
            final amt = p['amount'] ?? p['totalPrice'];
            if (amt is num) weekRev += amt.toDouble();
            if (amt is String) weekRev += double.tryParse(amt) ?? 0.0;
          }
        }
        values.add(weekRev);
      }
    } else {
      final count = range == AnalyticsTimeRange.sixMonths ? 6 : 12;
      for (int m = count - 1; m >= 0; m--) {
        final targetMonth = DateTime(now.year, now.month - m, 1);
        labels.add(DateFormat('MMM').format(targetMonth));

        double rev = 0;
        for (var p in parcels) {
          final pDate = _extractDate(
              p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
          if (pDate.year == targetMonth.year &&
              pDate.month == targetMonth.month) {
            final amt = p['amount'] ?? p['totalPrice'];
            if (amt is num) rev += amt.toDouble();
            if (amt is String) rev += double.tryParse(amt) ?? 0.0;
          }
        }
        values.add(rev);
      }
    }

    final double maxVal = values.isEmpty ? 1000 : (values.reduce(max) * 1.25);
    final safeMaxY = maxVal <= 0 ? 1000.0 : maxVal;

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
                'Revenue Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bar Graph (${range.label})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sales revenue generated during the selected period (in ₱)',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: safeMaxY,
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        _touchedBarIndex = -1;
                        return;
                      }
                      _touchedBarIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                color: _touchedBarIndex == index
                                    ? AppColors.navyPrimary
                                    : AppColors.textSecondary,
                                fontWeight: _touchedBarIndex == index
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppColors.surfaceMuted,
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(values.length, (index) {
                  final isTouched = index == _touchedBarIndex;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: values[index],
                        color: isTouched
                            ? AppColors.logoBlue
                            : AppColors.navySecondary,
                        width:
                            range == AnalyticsTimeRange.threeMonths ? 26 : 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          topRight: Radius.circular(5),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: safeMaxY,
                          color: AppColors.backgroundLight,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PLATFORM VOLUME SHARE CARD
  // -------------------------------------------------------------
  Widget _buildPlatformShareCard(List<Map<String, dynamic>> parcels) {
    final Map<String, int> counts = {
      AppConstants.platformShopee: 0,
      AppConstants.platformLazada: 0,
      'TikTok': 0,
      'Direct / Walk-in': 0,
    };

    for (var p in parcels) {
      final plat = p['platform'] as String? ?? 'Direct / Walk-in';
      if (plat.toLowerCase().contains('shopee')) {
        counts[AppConstants.platformShopee] =
            (counts[AppConstants.platformShopee] ?? 0) + 1;
      } else if (plat.toLowerCase().contains('lazada')) {
        counts[AppConstants.platformLazada] =
            (counts[AppConstants.platformLazada] ?? 0) + 1;
      } else if (plat.toLowerCase().contains('tiktok')) {
        counts['TikTok'] = (counts['TikTok'] ?? 0) + 1;
      } else {
        counts['Direct / Walk-in'] = (counts['Direct / Walk-in'] ?? 0) + 1;
      }
    }

    final total = parcels.isEmpty ? 1 : parcels.length;

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
          const Text(
            'Channel Volume Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...counts.entries.map((entry) {
            final percent = (entry.value / total) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navySecondary,
                        ),
                      ),
                      Text(
                        '${entry.value} orders (${percent.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: parcels.isEmpty ? 0 : entry.value / total,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        entry.key == AppConstants.platformShopee
                            ? AppColors.shopeeOrange
                            : entry.key == AppConstants.platformLazada
                                ? AppColors.lazadaBlue
                                : entry.key.toLowerCase().contains('tiktok')
                                    ? Colors.black
                                    : AppColors.statusDelivered,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// MODULE 8: EXCEL EXPORT BOTTOM SHEET (ADMIN ONLY WITH ZERO PERMISSIONS)
// -------------------------------------------------------------
class AdminExcelExportSheet extends ConsumerStatefulWidget {
  const AdminExcelExportSheet({super.key});

  @override
  ConsumerState<AdminExcelExportSheet> createState() =>
      _AdminExcelExportSheetState();
}

class _AdminExcelExportSheetState extends ConsumerState<AdminExcelExportSheet> {
  int _selectedDays = 90; // Default 3 Months
  bool _isExporting = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _intervals = [
    {'label': '1 Month (30D)', 'days': 30},
    {'label': '3 Months (90D)', 'days': 90},
    {'label': '6 Months (180D)', 'days': 180},
    {'label': '12 Months (365D)', 'days': 365},
  ];

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      final parcels = ref.read(allParcelsStreamProvider).asData?.value ?? [];
      final returns = ref.read(allReturnsStreamProvider).asData?.value ?? [];

      debugPrint('📊 [EXCEL_EXPORT] Generating and presenting share tray...');
      final result = await _ExcelExportEngine.exportAndShareParcels(
        parcels: parcels,
        returns: returns,
        intervalDays: _selectedDays,
      );

      debugPrint(
          '📊 [EXCEL_EXPORT] Share tray returned with status: ${result.status}');

      if (mounted) {
        navigator.pop();

        if (result.status == ShareResultStatus.success) {
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.statusDelivered,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workbook generated and shared successfully!',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.textSecondary,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Export cancelled.',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [EXCEL_EXPORT] Export error: $e\n$stack');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _errorMessage = cleanMsg;
        });
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cleanMsg,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.excelGreenTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_view_rounded,
                    color: AppColors.excelGreen, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organized Excel Export',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                    Text(
                      'Multi-sheet audit & platform summary',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: _isExporting
                    ? null
                    : () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Date Range Interval:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navySecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _intervals.map((item) {
              final isSelected = _selectedDays == item['days'];
              return ChoiceChip(
                label: Text(item['label'] as String),
                selected: isSelected,
                selectedColor: AppColors.excelGreen,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.navySecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: !_isExporting
                    ? (selected) {
                        if (selected) {
                          setState(() => _selectedDays = item['days'] as int);
                        }
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saves to local app cache and opens native Android Share. No broad storage permissions required.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusReturnedContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.dangerDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isExporting
                      ? null
                      : () => Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.excelGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: !_isExporting ? _handleExport : null,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(
                      _isExporting ? 'Generating...' : 'Export & Share .XLSX'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// MODULE 8: EXCEL GENERATION & SHARING ENGINE (WITH VALIDATION)
// -------------------------------------------------------------
class _ExcelExportEngine {
  static Future<ShareResult> exportAndShareParcels({
    required List<Map<String, dynamic>> parcels,
    required List<Map<String, dynamic>> returns,
    required int intervalDays,
  }) async {
    // ---------------------------------------------------------
    // 1. GLOBAL PARCEL VALIDATION CHECK
    // ---------------------------------------------------------
    if (parcels.isEmpty) {
      throw Exception(
          'No parcel records exist in your database to export. Please add or generate parcel data first.');
    }

    // ---------------------------------------------------------
    // 2. INTERVAL FILTERING & VALIDATION CHECK
    // ---------------------------------------------------------
    final cutoffDate = DateTime.now().subtract(Duration(days: intervalDays));
    final filteredParcels = parcels.where((p) {
      final orderDate =
          _parseDate(p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
      return orderDate == null || orderDate.isAfter(cutoffDate);
    }).toList();

    if (filteredParcels.isEmpty) {
      throw Exception(
        'No parcel records found for the selected interval (Past $intervalDays Days). Try selecting a wider interval or click "Generate" in the Sample Data Tool.',
      );
    }

    // ---------------------------------------------------------
    // 3. EXCEL WORKBOOK INITIALIZATION & STYLING
    // ---------------------------------------------------------
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    final currencyFormatter =
        NumberFormat.currency(locale: 'en_PH', symbol: '₱ ', decimalDigits: 2);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final subHeaderStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final totalRowStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
    );

    final platforms = [
      AppConstants.platformShopee,
      AppConstants.platformLazada,
      'TikTok',
      'Direct / Walk-in',
    ];

    // ---------------------------------------------------------
    // 4. PLATFORM TAB BUILDER
    // ---------------------------------------------------------
    for (final platform in platforms) {
      final sheetName = platform;
      final sheet = excel[sheetName];

      final headers = [
        'Order Date',
        'Tracking Number',
        'Courier',
        'Customer Name',
        'Contact Number',
        'Amount (PHP)',
        'Status',
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (var col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      final platformParcels = filteredParcels.where((p) {
        final plat = (p['platform'] ?? '').toString().toLowerCase();
        if (platform == 'Direct / Walk-in') {
          return !plat.contains('shopee') &&
              !plat.contains('lazada') &&
              !plat.contains('tiktok');
        }
        return plat.contains(platform.toLowerCase());
      }).toList();

      double platformTotalRevenue = 0.0;

      for (final p in platformParcels) {
        final rawDate =
            _parseDate(p['createdAt'] ?? p['dispatchedAt'] ?? p['dateShipped']);
        final dateStr = rawDate != null ? dateFormatter.format(rawDate) : 'N/A';
        final tracking = (p['trackingNumber'] ?? 'N/A').toString();
        final courier = (p['courier'] ?? 'Standard').toString();
        final customer = (p['customerName'] ?? 'N/A').toString();
        final contact = (p['contactNumber'] ?? '-').toString();
        final amt = p['amount'] ?? p['totalPrice'];
        double amount = 0.0;
        if (amt is num) amount = amt.toDouble();
        if (amt is String) amount = double.tryParse(amt) ?? 0.0;
        final status = (p['status'] ?? 'Pending').toString();

        platformTotalRevenue += amount;

        sheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(tracking),
          TextCellValue(courier),
          TextCellValue(customer),
          TextCellValue(contact),
          DoubleCellValue(amount),
          TextCellValue(status),
        ]);
      }

      final totalRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue('TOTALS'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('${platformParcels.length} Orders'),
        DoubleCellValue(platformTotalRevenue),
        TextCellValue(''),
      ]);

      for (var col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: totalRowIndex))
            .cellStyle = totalRowStyle;
      }

      sheet.setColumnWidth(0, 22.0);
      sheet.setColumnWidth(1, 26.0);
      sheet.setColumnWidth(2, 16.0);
      sheet.setColumnWidth(3, 22.0);
      sheet.setColumnWidth(4, 18.0);
      sheet.setColumnWidth(5, 16.0);
      sheet.setColumnWidth(6, 16.0);
    }

    // ---------------------------------------------------------
    // 5. CONSOLIDATED SUMMARY TAB
    // ---------------------------------------------------------
    const summarySheetName = 'Overall Summary';
    final summarySheet = excel[summarySheetName];

    summarySheet.appendRow([
      TextCellValue('SHIPTRACKER - CONSOLIDATED LOGISTICS & REVENUE AUDIT')
    ]);
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = headerStyle;
    summarySheet.appendRow([
      TextCellValue(
          'Interval: Past $intervalDays Days | Generated: ${dateFormatter.format(DateTime.now())}')
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    summarySheet.appendRow([TextCellValue('1. PERFORMANCE BY CHANNEL')]);
    final secARow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secARow))
        .cellStyle = subHeaderStyle;

    summarySheet.appendRow([
      TextCellValue('Platform'),
      TextCellValue('Total Parcels'),
      TextCellValue('Gross Revenue'),
    ]);

    double grandTotalRevenue = 0.0;
    int grandTotalParcels = 0;

    for (final platform in platforms) {
      final pList = filteredParcels.where((p) {
        final plat = (p['platform'] ?? '').toString().toLowerCase();
        if (platform == 'Direct / Walk-in') {
          return !plat.contains('shopee') &&
              !plat.contains('lazada') &&
              !plat.contains('tiktok');
        }
        return plat.contains(platform.toLowerCase());
      }).toList();

      final count = pList.length;
      final rev = pList.fold<double>(0.0, (total, p) {
        final amt = p['amount'] ?? p['totalPrice'];
        if (amt is num) return total + amt.toDouble();
        if (amt is String) return total + (double.tryParse(amt) ?? 0.0);
        return total;
      });

      grandTotalParcels += count;
      grandTotalRevenue += rev;

      summarySheet.appendRow([
        TextCellValue(platform),
        IntCellValue(count),
        TextCellValue(currencyFormatter.format(rev)),
      ]);
    }

    summarySheet.appendRow([
      TextCellValue('GRAND TOTAL'),
      IntCellValue(grandTotalParcels),
      TextCellValue(currencyFormatter.format(grandTotalRevenue)),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    summarySheet.appendRow([TextCellValue('2. RETURNS & LOSS AUDIT')]);
    final secBRow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secBRow))
        .cellStyle = subHeaderStyle;

    final returnRate = grandTotalParcels > 0
        ? (returns.length / grandTotalParcels * 100).toStringAsFixed(2)
        : '0.00';
    final returnLostValue = returns.fold<double>(0.0, (total, r) {
      final amt = r['amount'] ?? r['totalPrice'];
      if (amt is num) return total + amt.toDouble();
      if (amt is String) return total + (double.tryParse(amt) ?? 0.0);
      return total;
    });

    summarySheet.appendRow(
        [TextCellValue('Total Logged Returns'), IntCellValue(returns.length)]);
    summarySheet.appendRow(
        [TextCellValue('Return Rate'), TextCellValue('$returnRate %')]);
    summarySheet.appendRow([
      TextCellValue('Return Impact Value'),
      TextCellValue(currencyFormatter.format(returnLostValue))
    ]);

    summarySheet.setColumnWidth(0, 32.0);
    summarySheet.setColumnWidth(1, 24.0);
    summarySheet.setColumnWidth(2, 24.0);

    if (defaultSheet != summarySheetName && !platforms.contains(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    // ---------------------------------------------------------
    // 6. ENCODING & FILE SHARING
    // ---------------------------------------------------------
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file.');

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'ShipTracker_Report_${intervalDays}D_$timestamp.xlsx';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    return await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      subject: 'ShipTracker Consolidated Export ($fileName)',
      text:
          'Exported ShipTracker audit report for the past $intervalDays days.',
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val.runtimeType.toString().contains('Timestamp')) {
      try {
        return (val as dynamic).toDate();
      } catch (_) {}
    }
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
