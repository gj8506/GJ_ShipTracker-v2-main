// -------------------------------------------------------------
// CONFIDENCE LEVEL ENUM (Matches Unit Test)
// -------------------------------------------------------------
enum ConfidenceLevel {
  low('Low Confidence',
      'High variance or insufficient historical observations'),
  moderate('Moderate Confidence', 'Stable historical trend'),
  high('High Confidence', 'Strong statistical fit (R² > 0.70)');

  final String title;
  final String subtitle;
  const ConfidenceLevel(this.title, this.subtitle);
}

// -------------------------------------------------------------
// FORECAST HORIZON WITH MINIMUM THRESHOLDS
// -------------------------------------------------------------
enum ForecastHorizon {
  oneMonth(1, '1 Mo', 'Next Month', 3),
  threeMonths(3, '3 Mo', 'Next 3 Months', 4),
  sixMonths(6, '6 Mo', 'Next 6 Months', 6),
  twelveMonths(12, '12 Mo', 'Next 12 Months', 12);

  final int months;
  final String label;
  final String fullTitle;
  final int minRequiredMonths;

  const ForecastHorizon(
    this.months,
    this.label,
    this.fullTitle,
    this.minRequiredMonths,
  );
}

// -------------------------------------------------------------
// MONTHLY DATA POINT
// -------------------------------------------------------------
class MonthlyDataPoint {
  final int year;
  final int month;
  final double revenue;
  final int parcelCount;
  final String platform;

  const MonthlyDataPoint({
    required this.year,
    required this.month,
    required this.revenue,
    required this.parcelCount,
    this.platform = 'All',
  });

  String get label => '$year-${month.toString().padLeft(2, '0')}';
}

// -------------------------------------------------------------
// FORECAST POINT (LOWER, UPPER & PROJECTED VALUES)
// -------------------------------------------------------------
class ForecastPoint {
  final int year;
  final int month;
  final double projectedRevenue;
  final int projectedParcels;
  final double lowerBound;
  final double upperBound;

  const ForecastPoint({
    required this.year,
    required this.month,
    required this.projectedRevenue,
    required this.projectedParcels,
    required this.lowerBound,
    required this.upperBound,
  });

  String get label => '$year-${month.toString().padLeft(2, '0')}';
}

// -------------------------------------------------------------
// FORECAST RESULT (Includes hasSufficientData required by tests)
// -------------------------------------------------------------
class ForecastResult {
  final bool hasSufficientData;
  final List<ForecastPoint> forecastPoints;
  final double totalProjectedRevenue;
  final int totalProjectedParcels;
  final double growthRatePercent;
  final ConfidenceLevel confidence;
  final int historicalMonthsCount;
  final int requiredMonthsCount;
  final String insightSummary;

  const ForecastResult({
    required this.hasSufficientData,
    required this.forecastPoints,
    required this.totalProjectedRevenue,
    required this.totalProjectedParcels,
    required this.growthRatePercent,
    required this.confidence,
    required this.historicalMonthsCount,
    required this.requiredMonthsCount,
    required this.insightSummary,
  });

  static const zero = ForecastResult(
    hasSufficientData: false,
    forecastPoints: [],
    totalProjectedRevenue: 0.0,
    totalProjectedParcels: 0,
    growthRatePercent: 0.0,
    confidence: ConfidenceLevel.low,
    historicalMonthsCount: 0,
    requiredMonthsCount: 3,
    insightSummary: 'No historical shipments recorded.',
  );
}
