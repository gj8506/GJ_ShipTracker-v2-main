import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../analytics_screen.dart';
import '../../services/excel_export_service.dart';

class AdminExcelExportDialog extends ConsumerStatefulWidget {
  const AdminExcelExportDialog({super.key});

  @override
  ConsumerState<AdminExcelExportDialog> createState() =>
      _AdminExcelExportDialogState();
}

class _AdminExcelExportDialogState
    extends ConsumerState<AdminExcelExportDialog> {
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

    try {
      final parcels = ref.read(allParcelsStreamProvider).asData?.value ?? [];
      final returns = ref.read(allReturnsStreamProvider).asData?.value ?? [];

      await ExcelExportService.exportAndShareParcels(
        parcels: parcels,
        returns: returns,
        intervalDays: _selectedDays,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.successGreen,
            content: Text('Workbook generated and ready to share!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔔 [EXCEL_EXPORT] 2b. AdminExcelExportDialog build() called');
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        // CRITICAL: Finite constraints to prevent RenderBox was not laid out exception
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screenSize.height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusDelivered.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart,
                        color: AppColors.statusDelivered, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Organized Excel',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Select time interval for your records',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed:
                        _isExporting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Interval Selection Chips
              const Text(
                'Reporting Range',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intervals.map((item) {
                  final days = item['days'] as int;
                  final label = item['label'] as String;
                  final isSelected = _selectedDays == days;

                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor:
                        AppColors.statusDelivered.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.statusDelivered
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: _isExporting
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() => _selectedDays = days);
                            }
                          },
                  );
                }).toList(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                      color: AppColors.statusReturned, fontSize: 12),
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isExporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusDelivered,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isExporting ? null : _handleExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(_isExporting
                        ? 'Generating...'
                        : 'Export & Share .XLSX'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
