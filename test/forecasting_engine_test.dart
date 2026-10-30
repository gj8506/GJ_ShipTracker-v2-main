import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/forecasting/domain/forecast_models.dart';
import 'package:gjandasher_shiptracker/features/forecasting/domain/forecasting_engine.dart';

void main() {
  group('ForecastingEngine Unit Tests', () {
    test('Returns insufficientData when historical months are below minimum threshold', () {
      final minimalHistory = [
        const MonthlyDataPoint(year: 2026, month: 1, revenue: 10000, parcelCount: 50),
        const MonthlyDataPoint(year: 2026, month: 2, revenue: 12000, parcelCount: 60),
      ];

      // 12-Month forecast needs at least 12 historical months
      final result12 = ForecastingEngine.calculateForecast(
        history: minimalHistory,
        horizon: ForecastHorizon.twelveMonths,
      );
      expect(result12.hasSufficientData, false);
      expect(result12.forecastPoints, isEmpty);

      // 3-Month forecast needs at least 4 historical months
      final result3 = ForecastingEngine.calculateForecast(
        history: minimalHistory,
        horizon: ForecastHorizon.threeMonths,
      );
      expect(result3.hasSufficientData, false);
    });

    test('Computes upward growth forecast with high/moderate confidence', () {
      final upwardHistory = [
        const MonthlyDataPoint(year: 2025, month: 1, revenue: 20000, parcelCount: 100),
        const MonthlyDataPoint(year: 2025, month: 2, revenue: 25000, parcelCount: 125),
        const MonthlyDataPoint(year: 2025, month: 3, revenue: 30000, parcelCount: 150),
        const MonthlyDataPoint(year: 2025, month: 4, revenue: 35000, parcelCount: 175),
        const MonthlyDataPoint(year: 2025, month: 5, revenue: 40000, parcelCount: 200),
        const MonthlyDataPoint(year: 2025, month: 6, revenue: 45000, parcelCount: 225),
      ];

      final result = ForecastingEngine.calculateForecast(
        history: upwardHistory,
        horizon: ForecastHorizon.threeMonths,
      );

      expect(result.hasSufficientData, true);
      expect(result.forecastPoints.length, 3);
      expect(result.growthRatePercent, greaterThan(0));
      expect(result.confidence, isNot(ConfidenceLevel.low));
    });

    test('Calculates confidence intervals with valid lower and upper bounds', () {
      final fluctuatingHistory = [
        const MonthlyDataPoint(year: 2026, month: 1, revenue: 5000, parcelCount: 10),
        const MonthlyDataPoint(year: 2026, month: 2, revenue: 2000, parcelCount: 4),
        const MonthlyDataPoint(year: 2026, month: 3, revenue: 1500, parcelCount: 3),
        const MonthlyDataPoint(year: 2026, month: 4, revenue: 1000, parcelCount: 2),
      ];

      final result = ForecastingEngine.calculateForecast(
        history: fluctuatingHistory,
        horizon: ForecastHorizon.oneMonth,
      );

      expect(result.hasSufficientData, true);
      expect(result.forecastPoints.first.lowerBound, greaterThanOrEqualTo(0.0));
      expect(result.forecastPoints.first.upperBound, greaterThanOrEqualTo(result.forecastPoints.first.projectedRevenue));
    });
  });
}