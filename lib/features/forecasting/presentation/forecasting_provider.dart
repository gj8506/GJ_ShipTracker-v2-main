import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/forecast_models.dart';
import '../domain/forecasting_engine.dart';

final selectedHorizonProvider =
    StateProvider<ForecastHorizon>((ref) => ForecastHorizon.threeMonths);

final selectedPlatformProvider = StateProvider<String>((ref) => 'All');

/// Aggregates sales from Firestore grouped by year, month, and platform
final historicalSalesProvider =
    FutureProvider<List<MonthlyDataPoint>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection(AppConstants.collectionParcels)
      .where('status', isNotEqualTo: 'cancelled')
      .get();

  final Map<String,
          ({double revenue, int count, String platform, int year, int month})>
      buckets = {};

  for (final doc in snap.docs) {
    final data = doc.data();
    final rawDate =
        data['dateShipped'] ?? data['dispatchedAt'] ?? data['createdAt'];

    DateTime date = DateTime.now();
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    }

    final platform = (data['platform'] as String? ?? 'Direct / Walk-in').trim();
    final amount = (data['amount'] as num? ?? data['totalPrice'] as num? ?? 0.0)
        .toDouble();

    final key = '${date.year}-${date.month}_$platform';
    final existing = buckets[key];

    if (existing != null) {
      buckets[key] = (
        revenue: existing.revenue + amount,
        count: existing.count + 1,
        platform: platform,
        year: date.year,
        month: date.month,
      );
    } else {
      buckets[key] = (
        revenue: amount,
        count: 1,
        platform: platform,
        year: date.year,
        month: date.month,
      );
    }
  }

  return buckets.values
      .map((b) => MonthlyDataPoint(
            year: b.year,
            month: b.month,
            revenue: b.revenue,
            parcelCount: b.count,
            platform: b.platform,
          ))
      .toList();
});

/// Computes the forecast result based on active filters
final forecastResultProvider = Provider<ForecastResult>((ref) {
  final historyAsync = ref.watch(historicalSalesProvider);
  final horizon = ref.watch(selectedHorizonProvider);
  final platform = ref.watch(selectedPlatformProvider);

  final rawHistory = historyAsync.value ?? [];

  // Filter by platform if specific channel selected
  final filtered = platform == 'All'
      ? _combinePlatforms(rawHistory)
      : rawHistory
          .where(
              (p) => p.platform.toLowerCase().contains(platform.toLowerCase()))
          .toList();

  return ForecastingEngine.calculateForecast(
    history: filtered,
    horizon: horizon,
  );
});

List<MonthlyDataPoint> _combinePlatforms(List<MonthlyDataPoint> items) {
  final Map<String, ({double revenue, int count, int year, int month})>
      grouped = {};
  for (var i in items) {
    final key = '${i.year}-${i.month}';
    final existing = grouped[key];
    if (existing != null) {
      grouped[key] = (
        revenue: existing.revenue + i.revenue,
        count: existing.count + i.parcelCount,
        year: i.year,
        month: i.month,
      );
    } else {
      grouped[key] = (
        revenue: i.revenue,
        count: i.parcelCount,
        year: i.year,
        month: i.month,
      );
    }
  }

  return grouped.values
      .map((g) => MonthlyDataPoint(
            year: g.year,
            month: g.month,
            revenue: g.revenue,
            parcelCount: g.count,
            platform: 'All',
          ))
      .toList();
}
