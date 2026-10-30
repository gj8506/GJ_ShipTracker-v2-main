import 'dart:math';
import 'forecast_models.dart';

class ForecastingEngine {
  /// Calculates linear regression forecasts when historical data satisfies
  /// horizon thresholds. Returns hasSufficientData: false otherwise.
  static ForecastResult calculateForecast({
    required List<MonthlyDataPoint> history,
    required ForecastHorizon horizon,
  }) {
    // 1. Sort historical records chronologically
    final sorted = List<MonthlyDataPoint>.from(history)
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });

    // 2. Enforce minimum historical data thresholds required by unit tests
    if (sorted.length < horizon.minRequiredMonths) {
      return ForecastResult(
        hasSufficientData: false,
        forecastPoints: const [],
        totalProjectedRevenue: 0.0,
        totalProjectedParcels: 0,
        growthRatePercent: 0.0,
        confidence: ConfidenceLevel.low,
        historicalMonthsCount: sorted.length,
        requiredMonthsCount: horizon.minRequiredMonths,
        insightSummary:
            'The selected ${horizon.fullTitle} forecast requires at least ${horizon.minRequiredMonths} recorded historical months to establish a valid trend. Currently, only ${sorted.length} month(s) exist in your system.',
      );
    }

    // 3. Compute OLS Linear Regression (y = mx + b)
    final n = sorted.length;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = sorted[i].revenue;
      sumX += x;
      sumY += y;
      sumXY += (x * y);
      sumX2 += (x * x);
    }

    final denominator = (n * sumX2) - (sumX * sumX);
    final slope =
        denominator != 0 ? ((n * sumXY) - (sumX * sumY)) / denominator : 0.0;
    final intercept = (sumY - (slope * sumX)) / n;

    // 4. Calculate historical baseline for parcels
    double totalHistoricalRevenue = 0;
    int totalHistoricalParcels = 0;
    for (var p in sorted) {
      totalHistoricalRevenue += p.revenue;
      totalHistoricalParcels += p.parcelCount;
    }
    final avgPricePerParcel = totalHistoricalParcels > 0
        ? (totalHistoricalRevenue / totalHistoricalParcels)
        : 1000.0;

    // 5. Generate future projection points
    final lastEntry = sorted.last;
    int curYear = lastEntry.year;
    int curMonth = lastEntry.month;

    final List<ForecastPoint> points = [];
    double totalProjectedRevenue = 0;
    int totalProjectedParcels = 0;

    for (int step = 1; step <= horizon.months; step++) {
      curMonth++;
      if (curMonth > 12) {
        curMonth = 1;
        curYear++;
      }

      final xTarget = (n - 1) + step;
      double projectedRev = intercept + (slope * xTarget);
      if (projectedRev < 0) projectedRev = sorted.last.revenue * 0.75;

      final projectedCount = max(1, (projectedRev / avgPricePerParcel).round());

      // Standard error margin envelope
      final margin = max(projectedRev * 0.15, 500.0);
      final lowerBound = max(0.0, projectedRev - margin);
      final upperBound = projectedRev + margin;

      points.add(ForecastPoint(
        year: curYear,
        month: curMonth,
        projectedRevenue: projectedRev,
        projectedParcels: projectedCount,
        lowerBound: lowerBound,
        upperBound: upperBound,
      ));

      totalProjectedRevenue += projectedRev;
      totalProjectedParcels += projectedCount;
    }

    // 6. Growth Rate calculation
    final firstRevenue = sorted.first.revenue;
    final lastRevenue = sorted.last.revenue;
    final growthRate = firstRevenue > 0
        ? (((lastRevenue - firstRevenue) / firstRevenue) * 100)
        : (slope >= 0 ? 5.0 : -5.0);

    // 7. Statistical Confidence
    final ConfidenceLevel confidence;
    if (n >= 6 && slope >= 0) {
      confidence = ConfidenceLevel.high;
    } else {
      confidence = ConfidenceLevel.moderate;
    }

    final insight = slope >= 0
        ? 'Steady upward sales trajectory. Projected to grow by ~${growthRate.abs().toStringAsFixed(1)}% over the period.'
        : 'Downward variance observed. Review low-performing courier channels and return rates.';

    return ForecastResult(
      hasSufficientData: true,
      forecastPoints: points,
      totalProjectedRevenue: totalProjectedRevenue,
      totalProjectedParcels: totalProjectedParcels,
      growthRatePercent: growthRate,
      confidence: confidence,
      historicalMonthsCount: n,
      requiredMonthsCount: horizon.minRequiredMonths,
      insightSummary: insight,
    );
  }
}
