import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_data.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

final selectedIntervalProvider = StateProvider<AnalyticsInterval>((ref) {
  return AnalyticsInterval.oneMonth;
});

final selectedMetricProvider = StateProvider<AnalyticsMetric>((ref) {
  return AnalyticsMetric.salesAmount;
});

final isSampleDataLoadingProvider = StateProvider<bool>((ref) => false);

final analyticsSummaryProvider = FutureProvider<AnalyticsSummary>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final interval = ref.watch(selectedIntervalProvider);
  return repo.getAnalytics(interval: interval);
});
