import 'package:flutter/material.dart';

enum AnalyticsInterval {
  oneMonth,
  threeMonths,
  sixMonths,
  twelveMonths;

  String get label {
    switch (this) {
      case AnalyticsInterval.oneMonth:
        return '1 Month';
      case AnalyticsInterval.threeMonths:
        return '3 Months';
      case AnalyticsInterval.sixMonths:
        return '6 Months';
      case AnalyticsInterval.twelveMonths:
        return '12 Months';
    }
  }

  int get monthCount {
    switch (this) {
      case AnalyticsInterval.oneMonth:
        return 1;
      case AnalyticsInterval.threeMonths:
        return 3;
      case AnalyticsInterval.sixMonths:
        return 6;
      case AnalyticsInterval.twelveMonths:
        return 12;
    }
  }
}

enum AnalyticsMetric {
  salesAmount,
  platesCount;

  String get label {
    switch (this) {
      case AnalyticsMetric.salesAmount:
        return 'Sales (₱)';
      case AnalyticsMetric.platesCount:
        return 'Plates Sold';
    }
  }
}

class PlatformSales {
  final String platform;
  final double amount;
  final int count;
  final Color color;

  const PlatformSales({
    required this.platform,
    required this.amount,
    required this.count,
    required this.color,
  });
}

class PlateStyleBreakdown {
  final String style;
  final int count;
  final double amount;

  const PlateStyleBreakdown({
    required this.style,
    required this.count,
    required this.amount,
  });
}

class TimeBucketData {
  final String label;
  final DateTime date;
  final double totalSales;
  final int totalCount;
  final Map<String, double> platformSales;
  final Map<String, int> platformCount;

  const TimeBucketData({
    required this.label,
    required this.date,
    required this.totalSales,
    required this.totalCount,
    required this.platformSales,
    required this.platformCount,
  });
}

class AnalyticsSummary {
  final double totalSales;
  final int parcelsCount;
  final int returnsCount;
  final double returnRate;
  final List<TimeBucketData> chartBuckets;
  final List<PlateStyleBreakdown> plateStyles;
  final Map<String, PlatformSales> platformTotals;

  const AnalyticsSummary({
    required this.totalSales,
    required this.parcelsCount,
    required this.returnsCount,
    required this.returnRate,
    required this.chartBuckets,
    required this.plateStyles,
    required this.platformTotals,
  });

  factory AnalyticsSummary.empty() {
    return const AnalyticsSummary(
      totalSales: 0.0,
      parcelsCount: 0,
      returnsCount: 0,
      returnRate: 0.0,
      chartBuckets: [],
      plateStyles: [],
      platformTotals: {},
    );
  }
}
