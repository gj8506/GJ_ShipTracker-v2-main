import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/analytics_data.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Platform Color Palette
  static const Color colorShopee = Color(0xFFEE4D2D);
  static const Color colorLazada = Color(0xFF0F146D);
  static const Color colorTikTok = Color(0xFF6FD0F5);
  static const Color colorDirect = Color(0xFF1E7A46);

  static Color getPlatformColor(String platform) {
    switch (platform.trim().toLowerCase()) {
      case 'shopee':
        return colorShopee;
      case 'lazada':
        return colorLazada;
      case 'tiktok':
      case 'tiktok shop':
        return colorTikTok;
      default:
        return colorDirect;
    }
  }

  // Safe Date Parser (handles Timestamp, ISO String, or int)
  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  // 1. Fetch & Aggregate Analytics
  Future<AnalyticsSummary> getAnalytics({
    required AnalyticsInterval interval,
  }) async {
    final now = DateTime.now();
    final startDate =
        DateTime(now.year, now.month - interval.monthCount, now.day);

    final snapshot =
        await _firestore.collection(AppConstants.collectionParcels).get();

    double totalSales = 0.0;
    int parcelsCount = 0;
    int returnsCount = 0;

    final Map<String, double> platformAmountMap = {
      'Shopee': 0.0,
      'Lazada': 0.0,
      'TikTok': 0.0,
      'Direct': 0.0,
    };
    final Map<String, int> platformCountMap = {
      'Shopee': 0,
      'Lazada': 0,
      'TikTok': 0,
      'Direct': 0,
    };

    final Map<String, int> styleCountMap = {};
    final Map<String, double> styleAmountMap = {};

    // Generate buckets according to selected interval granularity
    final List<TimeBucketData> rawBuckets =
        _createBuckets(interval, startDate, now);
    final List<Map<String, dynamic>> validOrders = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final orderDate = _parseDate(data['orderDate'] ?? data['createdAt']);
      if (orderDate == null || orderDate.isBefore(startDate)) continue;

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final isReturned = status.contains('return');

      final rawAmount =
          data['amount'] ?? data['totalAmount'] ?? data['price'] ?? 0;
      final amount = (rawAmount is num) ? rawAmount.toDouble() : 0.0;

      final rawPlatform = (data['platform'] ?? 'Direct').toString().trim();
      final platform = _canonicalPlatform(rawPlatform);
      final style = (data['style'] ?? data['plateStyle'] ?? 'Standard Embossed')
          .toString()
          .trim();

      if (isReturned) {
        returnsCount++;
        // Excluded from sales, but counted in parcels activity
      } else {
        totalSales += amount;
        parcelsCount++;

        platformAmountMap[platform] =
            (platformAmountMap[platform] ?? 0.0) + amount;
        platformCountMap[platform] = (platformCountMap[platform] ?? 0) + 1;

        styleCountMap[style] = (styleCountMap[style] ?? 0) + 1;
        styleAmountMap[style] = (styleAmountMap[style] ?? 0.0) + amount;

        validOrders.add({
          'date': orderDate,
          'amount': amount,
          'platform': platform,
        });
      }
    }

    // Populate chart buckets
    final chartBuckets = _populateBuckets(rawBuckets, validOrders, interval);

    // Platform Breakdown
    final Map<String, PlatformSales> platformTotals = {};
    for (final p in platformAmountMap.keys) {
      platformTotals[p] = PlatformSales(
        platform: p,
        amount: platformAmountMap[p] ?? 0.0,
        count: platformCountMap[p] ?? 0,
        color: getPlatformColor(p),
      );
    }

    // Plate Style Breakdown
    final List<PlateStyleBreakdown> plateStyles =
        styleCountMap.entries.map((e) {
      return PlateStyleBreakdown(
        style: e.key,
        count: e.value,
        amount: styleAmountMap[e.key] ?? 0.0,
      );
    }).toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    final totalOrdersEvaluated = parcelsCount + returnsCount;
    final returnRate = totalOrdersEvaluated > 0
        ? (returnsCount / totalOrdersEvaluated) * 100.0
        : 0.0;

    return AnalyticsSummary(
      totalSales: totalSales,
      parcelsCount: parcelsCount,
      returnsCount: returnsCount,
      returnRate: returnRate,
      chartBuckets: chartBuckets,
      plateStyles: plateStyles,
      platformTotals: platformTotals,
    );
  }

  String _canonicalPlatform(String p) {
    final lower = p.toLowerCase();
    if (lower.contains('shopee')) return 'Shopee';
    if (lower.contains('lazada')) return 'Lazada';
    if (lower.contains('tiktok')) return 'TikTok';
    return 'Direct';
  }

  List<TimeBucketData> _createBuckets(
      AnalyticsInterval interval, DateTime start, DateTime end) {
    final List<TimeBucketData> list = [];
    if (interval == AnalyticsInterval.oneMonth) {
      for (int i = 0; i < 4; i++) {
        final bucketDate = start.add(Duration(days: i * 7));
        list.add(TimeBucketData(
          label: 'W${i + 1}',
          date: bucketDate,
          totalSales: 0,
          totalCount: 0,
          platformSales: {},
          platformCount: {},
        ));
      }
    } else if (interval == AnalyticsInterval.threeMonths) {
      for (int i = 0; i < 6; i++) {
        final bucketDate = start.add(Duration(days: i * 15));
        list.add(TimeBucketData(
          label: 'P${i + 1}',
          date: bucketDate,
          totalSales: 0,
          totalCount: 0,
          platformSales: {},
          platformCount: {},
        ));
      }
    } else {
      final months = interval == AnalyticsInterval.sixMonths ? 6 : 12;
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      for (int i = 0; i < months; i++) {
        final d = DateTime(start.year, start.month + i, 1);
        list.add(TimeBucketData(
          label: monthNames[d.month - 1],
          date: d,
          totalSales: 0,
          totalCount: 0,
          platformSales: {},
          platformCount: {},
        ));
      }
    }
    return list;
  }

  List<TimeBucketData> _populateBuckets(
    List<TimeBucketData> templates,
    List<Map<String, dynamic>> orders,
    AnalyticsInterval interval,
  ) {
    final result = <TimeBucketData>[];

    for (int i = 0; i < templates.length; i++) {
      final current = templates[i];
      final nextDate = (i + 1 < templates.length)
          ? templates[i + 1].date
          : DateTime.now().add(const Duration(days: 30));

      double sales = 0.0;
      int count = 0;
      final Map<String, double> pSales = {
        'Shopee': 0,
        'Lazada': 0,
        'TikTok': 0,
        'Direct': 0
      };
      final Map<String, int> pCount = {
        'Shopee': 0,
        'Lazada': 0,
        'TikTok': 0,
        'Direct': 0
      };

      for (final o in orders) {
        final oDate = o['date'] as DateTime;
        final oAmount = o['amount'] as double;
        final oPlat = o['platform'] as String;

        bool belongs = false;
        if (interval == AnalyticsInterval.sixMonths ||
            interval == AnalyticsInterval.twelveMonths) {
          belongs = oDate.year == current.date.year &&
              oDate.month == current.date.month;
        } else {
          belongs = (oDate.isAfter(current.date) ||
                  oDate.isAtSameMomentAs(current.date)) &&
              oDate.isBefore(nextDate);
        }

        if (belongs) {
          sales += oAmount;
          count++;
          pSales[oPlat] = (pSales[oPlat] ?? 0.0) + oAmount;
          pCount[oPlat] = (pCount[oPlat] ?? 0) + 1;
        }
      }

      result.add(TimeBucketData(
        label: current.label,
        date: current.date,
        totalSales: sales,
        totalCount: count,
        platformSales: pSales,
        platformCount: pCount,
      ));
    }
    return result;
  }

  // 2. Generate Sample Parcels for Debug
  Future<void> generateSampleParcels() async {
    final batch = _firestore.batch();
    final random = Random();
    final now = DateTime.now();

    final platforms = ['Shopee', 'Lazada', 'TikTok', 'Direct'];
    final plateStyles = [
      'Standard Embossed',
      'Carbon Fiber Sport',
      'Thai Concept Slim',
      'Acrylic Clear Pro',
      'Matte Black Elite',
    ];

    // Generate 50 realistic parcels across past 12 months
    for (int i = 0; i < 50; i++) {
      final docRef =
          _firestore.collection(AppConstants.collectionParcels).doc();
      final daysAgo = random.nextInt(360);
      final orderDate =
          now.subtract(Duration(days: daysAgo, hours: random.nextInt(24)));
      final platform = platforms[random.nextInt(platforms.length)];
      final style = plateStyles[random.nextInt(plateStyles.length)];
      final price = 350.0 + (random.nextInt(10) * 50.0); // ₱350 to ₱800
      final isReturned = random.nextDouble() < 0.10; // ~10% return rate

      batch.set(docRef, {
        'trackingNumber': 'SMPL-${100000 + i}',
        'platform': platform,
        'style': style,
        'amount': price,
        'status': isReturned ? 'Returned' : 'Delivered',
        'orderDate': Timestamp.fromDate(orderDate),
        'createdAt': Timestamp.fromDate(orderDate),
        'isSample': true,
      });
    }

    await batch.commit();
  }

  // 3. Delete Sample Parcels
  Future<int> deleteSampleParcels() async {
    final query = await _firestore
        .collection(AppConstants.collectionParcels)
        .where('isSample', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return query.docs.length;
  }
}
