import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';

class ExcelExportService {
  /// Main entry point to generate and share the workbook
  static Future<void> exportAndShareParcels({
    required List<Map<String, dynamic>> parcels,
    required List<Map<String, dynamic>> returns,
    required int intervalDays,
  }) async {
    // 1. Initialize fresh Excel instance
    final excel = Excel.createExcel();

    // The default sheet is usually 'Sheet1'; rename or delete it later
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    // Filter parcels by time range
    final cutoffDate = DateTime.now().subtract(Duration(days: intervalDays));
    final filteredParcels = parcels.where((p) {
      final orderDate =
          _parseDate(p['orderDate'] ?? p['createdAt'] ?? p['date']);
      return orderDate == null || orderDate.isAfter(cutoffDate);
    }).toList();

    // Formatter helpers
    final currencyFormatter =
        NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    // Header styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'), // Dark Slate
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final subHeaderStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#3B82F6'), // Primary Blue
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final totalRowStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
    );

    // -------------------------------------------------------------------------
    // 2. GENERATE PLATFORM-SPECIFIC SHEETS (Shopee, Lazada, TikTok Shop, etc.)
    // -------------------------------------------------------------------------
    final platforms = [
      AppConstants.platformShopee,
      AppConstants.platformLazada,
      AppConstants.platformTikTok,
    ];

    for (final platform in platforms) {
      final sheetName = platform;
      final sheet = excel[sheetName];

      // Define Table Headers
      final headers = [
        'Order Date',
        'Tracking Number',
        'Courier',
        'Customer Name',
        'Plate Text',
        'Style',
        'Qty',
        'Amount (PHP)',
        'Status',
      ];

      // Append header row
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (var col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      // Filter parcels for this platform
      final platformParcels = filteredParcels.where((p) {
        final plat =
            (p['platform'] ?? p['salesChannel'] ?? '').toString().toLowerCase();
        return plat.contains(platform.toLowerCase());
      }).toList();

      int platformTotalQty = 0;
      double platformTotalRevenue = 0.0;

      for (final p in platformParcels) {
        final rawDate =
            _parseDate(p['orderDate'] ?? p['createdAt'] ?? p['date']);
        final dateStr = rawDate != null ? dateFormatter.format(rawDate) : 'N/A';
        final tracking =
            (p['trackingNumber'] ?? p['tracking'] ?? 'N/A').toString();
        final courier = (p['courier'] ?? 'Standard').toString();
        final customer = (p['customerName'] ?? p['buyer'] ?? 'N/A').toString();
        final plateText = (p['plateText'] ?? p['customText'] ?? '-').toString();
        final style = (p['style'] ?? p['plateStyle'] ?? '-').toString();
        final qty = int.tryParse(p['quantity']?.toString() ?? '1') ?? 1;
        final amount = double.tryParse(p['totalAmount']?.toString() ??
                p['amount']?.toString() ??
                '0') ??
            0.0;
        final status = (p['status'] ?? 'Pending').toString();

        platformTotalQty += qty;
        platformTotalRevenue += amount;

        sheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(tracking),
          TextCellValue(courier),
          TextCellValue(customer),
          TextCellValue(plateText),
          TextCellValue(style),
          IntCellValue(qty),
          DoubleCellValue(amount),
          TextCellValue(status),
        ]);
      }

      // Bottom Totals Row
      final totalRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue('TOTALS'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(platformTotalQty),
        DoubleCellValue(platformTotalRevenue),
        TextCellValue('${platformParcels.length} Orders'),
      ]);

      for (var col = 0; col < headers.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: totalRowIndex))
            .cellStyle = totalRowStyle;
      }

      // Set readable column widths (estimate in characters)
      sheet.setColumnWidth(0, 22.0); // Order Date
      sheet.setColumnWidth(1, 24.0); // Tracking
      sheet.setColumnWidth(2, 16.0); // Courier
      sheet.setColumnWidth(3, 22.0); // Customer
      sheet.setColumnWidth(4, 18.0); // Plate Text
      sheet.setColumnWidth(5, 14.0); // Style
      sheet.setColumnWidth(6, 10.0); // Qty
      sheet.setColumnWidth(7, 16.0); // Amount
      sheet.setColumnWidth(8, 16.0); // Status
    }

    // -------------------------------------------------------------------------
    // 3. OVERALL SUMMARY SHEET
    // -------------------------------------------------------------------------
    const summarySheetName = 'Overall Summary';
    final summarySheet = excel[summarySheetName];

    // Title Banner
    summarySheet.appendRow(
        [TextCellValue('SHIPTRACKER - CONSOLIDATED AUDIT & REVENUE REPORT')]);
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = headerStyle;
    summarySheet.appendRow([
      TextCellValue(
          'Interval: Past $intervalDays Days | Generated: ${dateFormatter.format(DateTime.now())}')
    ]);
    summarySheet.appendRow([TextCellValue('')]); // Blank line

    // SECTION A: Performance by Platform
    summarySheet.appendRow([TextCellValue('1. PERFORMANCE BY SALES CHANNEL')]);
    final secARow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secARow))
        .cellStyle = subHeaderStyle;

    summarySheet.appendRow([
      TextCellValue('Platform'),
      TextCellValue('Total Parcels'),
      TextCellValue('Total Items (Qty)'),
      TextCellValue('Gross Revenue'),
    ]);

    double grandTotalRevenue = 0.0;
    int grandTotalParcels = 0;
    int grandTotalQty = 0;

    for (final platform in platforms) {
      final pList = filteredParcels.where((p) {
        final plat =
            (p['platform'] ?? p['salesChannel'] ?? '').toString().toLowerCase();
        return plat.contains(platform.toLowerCase());
      }).toList();

      final count = pList.length;
      final qty = pList.fold<int>(
          0,
          (sum, p) =>
              sum + (int.tryParse(p['quantity']?.toString() ?? '1') ?? 1));
      final rev = pList.fold<double>(
          0.0,
          (sum, p) =>
              sum +
              (double.tryParse(p['totalAmount']?.toString() ??
                      p['amount']?.toString() ??
                      '0') ??
                  0.0));

      grandTotalParcels += count;
      grandTotalQty += qty;
      grandTotalRevenue += rev;

      summarySheet.appendRow([
        TextCellValue(platform),
        IntCellValue(count),
        IntCellValue(qty),
        TextCellValue(currencyFormatter.format(rev)),
      ]);
    }

    // Summary Totals
    summarySheet.appendRow([
      TextCellValue('GRAND TOTAL'),
      IntCellValue(grandTotalParcels),
      IntCellValue(grandTotalQty),
      TextCellValue(currencyFormatter.format(grandTotalRevenue)),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // SECTION B: Status Breakdown
    summarySheet.appendRow([TextCellValue('2. ORDER STATUS BREAKDOWN')]);
    final secBRow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secBRow))
        .cellStyle = subHeaderStyle;

    summarySheet.appendRow([
      TextCellValue('Status'),
      TextCellValue('Parcels Count'),
      TextCellValue('% of Total')
    ]);

    final statusMap = <String, int>{};
    for (final p in filteredParcels) {
      final st = (p['status'] ?? 'Unknown').toString();
      statusMap[st] = (statusMap[st] ?? 0) + 1;
    }

    statusMap.forEach((status, count) {
      final pct = grandTotalParcels > 0
          ? (count / grandTotalParcels * 100).toStringAsFixed(1)
          : '0.0';
      summarySheet.appendRow([
        TextCellValue(status),
        IntCellValue(count),
        TextCellValue('$pct %'),
      ]);
    });
    summarySheet.appendRow([TextCellValue('')]);

    // SECTION C: Monthly Trajectory
    summarySheet.appendRow([TextCellValue('3. MONTHLY TRAJECTORY')]);
    final secCRow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secCRow))
        .cellStyle = subHeaderStyle;

    summarySheet.appendRow([
      TextCellValue('Month'),
      TextCellValue('Parcels Count'),
      TextCellValue('Gross Revenue')
    ]);

    final monthlyMap =
        <String, List<double>>{}; // Key: 'yyyy-MM', Value: [count, revenue]
    for (final p in filteredParcels) {
      final date = _parseDate(p['orderDate'] ?? p['createdAt'] ?? p['date']);
      if (date != null) {
        final key = DateFormat('yyyy-MM').format(date);
        final amt = double.tryParse(p['totalAmount']?.toString() ??
                p['amount']?.toString() ??
                '0') ??
            0.0;
        monthlyMap.putIfAbsent(key, () => [0.0, 0.0]);
        monthlyMap[key]![0] += 1;
        monthlyMap[key]![1] += amt;
      }
    }

    final sortedMonths = monthlyMap.keys.toList()..sort();
    for (final m in sortedMonths) {
      summarySheet.appendRow([
        TextCellValue(m),
        IntCellValue(monthlyMap[m]![0].toInt()),
        TextCellValue(currencyFormatter.format(monthlyMap[m]![1])),
      ]);
    }
    summarySheet.appendRow([TextCellValue('')]);

    // SECTION D: Returns & Lost Value
    summarySheet.appendRow([TextCellValue('4. RETURNS & DISPUTES AUDIT')]);
    final secDRow = summarySheet.maxRows - 1;
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: secDRow))
        .cellStyle = subHeaderStyle;

    summarySheet.appendRow([
      TextCellValue('Metric'),
      TextCellValue('Value'),
    ]);

    final totalReturnsCount = returns.length;
    final returnRate = grandTotalParcels > 0
        ? (totalReturnsCount / grandTotalParcels * 100).toStringAsFixed(2)
        : '0.00';
    final returnLostValue = returns.fold<double>(
      0.0,
      (sum, r) =>
          sum +
          (double.tryParse(r['amount']?.toString() ??
                  r['totalAmount']?.toString() ??
                  '0') ??
              0.0),
    );

    summarySheet.appendRow([
      TextCellValue('Total Logged Returns'),
      IntCellValue(totalReturnsCount)
    ]);
    summarySheet.appendRow(
        [TextCellValue('Return Rate'), TextCellValue('$returnRate %')]);
    summarySheet.appendRow([
      TextCellValue('Estimated Return Value Impact'),
      TextCellValue(currencyFormatter.format(returnLostValue))
    ]);

    // Set widths for Overall Summary sheet
    summarySheet.setColumnWidth(0, 32.0);
    summarySheet.setColumnWidth(1, 22.0);
    summarySheet.setColumnWidth(2, 22.0);
    summarySheet.setColumnWidth(3, 24.0);

    // Delete unused initial default sheet if created
    if (defaultSheet != summarySheetName && !platforms.contains(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    // -------------------------------------------------------------------------
    // 4. WRITE FILE TO TEMPORARY DIRECTORY & INVOKE SHARE_PLUS
    // -------------------------------------------------------------------------
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'ShipTracker_Report_${intervalDays}D_$timestamp.xlsx';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    // 5. Open Android/iOS native system sharesheet
    await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      subject: 'ShipTracker Consolidated Export ($fileName)',
      text: 'Exported ShipTracker report for the past $intervalDays days.',
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
    if (val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }
}
