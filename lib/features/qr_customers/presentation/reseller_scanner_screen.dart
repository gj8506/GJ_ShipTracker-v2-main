import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../parcels/domain/parcel_model.dart';
import 'customer_providers.dart';

class ResellerScannerScreen extends ConsumerStatefulWidget {
  const ResellerScannerScreen({super.key});

  @override
  ConsumerState<ResellerScannerScreen> createState() =>
      _ResellerScannerScreenState();
}

class _ResellerScannerScreenState extends ConsumerState<ResellerScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualSearchCtrl = TextEditingController();
  bool _isProcessing = false;
  bool _torchEnabled = false;

  /// Set in [dispose] so late async callbacks never touch a dead camera or
  /// call `setState` after the screen is gone.
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    // Release the platform camera session. Skipping this leaves the previous
    // scan's camera alive, so consecutive scans pile up native resources until
    // the app crashes.
    _scannerController.dispose();
    _manualSearchCtrl.dispose();
    super.dispose();
  }

  /// Stops decoding frames while a result sheet is open.
  Future<void> _pauseScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // The controller can already be gone when the user backs out mid-scan.
    }
  }

  /// Restarts the camera for the next scan.
  Future<void> _resumeScanner() async {
    if (_isDisposed) return;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // Thrown when a start is already in flight (fast double taps) or the
      // controller was disposed; the camera is running or no longer needed.
    } catch (_) {
      // Ignored on purpose: the next scan retries the camera.
    }
  }

  /// Re-arms the scanner after a scan was rejected or dismissed.
  void _finishScan() {
    if (_isDisposed) return;
    _resumeScanner();
    if (mounted) setState(() => _isProcessing = false);
  }

  void _showScanMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.statusReturned,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _handleBarcode(String rawCode) async {
    if (_isDisposed || _isProcessing) return;

    final cleanCode = rawCode.trim();
    if (cleanCode.isEmpty) return;

    setState(() => _isProcessing = true);

    // Stop the camera before the lookups: every remaining detection frame
    // would otherwise queue another query while this one is still running.
    await _pauseScanner();

    try {
      if (!cleanCode.toUpperCase().startsWith('GJAS1:')) {
        _showScanMessage(
            'Invalid QR! Only official GJandAsher customer QR codes are accepted.');
        _finishScan();
        return;
      }

      final customerId = cleanCode.substring(6).trim();
      final repo = ref.read(customerRepositoryProvider);
      final customer = await repo.getCustomerById(customerId);

      if (!mounted || _isDisposed) return;
      if (customer == null) {
        _showScanMessage('Customer record not found in system.');
        _finishScan();
        return;
      }

      // 1. Fetch Previous Parcel Data (Courier Prefs)
      final lastParcel = await repo.getMostRecentParcel(customer.name);

      if (!mounted || _isDisposed) return;

      // 2. Fetch Pending Custom Plate Orders (Robust Search)
      Map<String, dynamic>? pendingOrder;
      String? pendingOrderId;

      QuerySnapshot orderSnap;

      // First try searching by exact User ID, fallback to searching by Customer Name
      if (customer.linkedUid != null && customer.linkedUid!.isNotEmpty) {
        orderSnap = await FirebaseFirestore.instance
            .collection('order_requests')
            .where('userId', isEqualTo: customer.linkedUid)
            .get();
      } else {
        orderSnap = await FirebaseFirestore.instance
            .collection('order_requests')
            .where('customerName', isEqualTo: customer.name)
            .get();
      }

      if (!mounted || _isDisposed) return;

      final pendingDocs = orderSnap.docs.where((doc) {
        final status = (doc.data() as Map<String, dynamic>)['status'] as String?;
        return status?.toUpperCase() == 'PENDING' || status == 'Pending Quote';
      }).toList();

      if (pendingDocs.isNotEmpty) {
        pendingDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = aData?['createdAt'] as Timestamp?;
          final bTime = bData?['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
        pendingOrderId = pendingDocs.first.id;
        pendingOrder = pendingDocs.first.data() as Map<String, dynamic>;
      }

      _showConfirmationSheet(
          customer, lastParcel, pendingOrder, pendingOrderId);
    } catch (_) {
      // Offline or a Firestore failure must not leave the scanner stuck in the
      // processing state, otherwise it appears frozen after one bad scan.
      if (mounted && !_isDisposed) {
        _showScanMessage('Could not read this QR code. Please try again.');
        _finishScan();
      }
    }
  }

  void _showConfirmationSheet(
    CustomerModel customer,
    ParcelModel? lastParcel,
    Map<String, dynamic>? pendingOrder,
    String? pendingOrderId,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.logoBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppColors.logoBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Buy Now Uli',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.tealDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            customer.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Contact: ',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        customer.contactNumber.isNotEmpty
                            ? customer.contactNumber
                            : 'None',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Address: ',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        customer.address.isNotEmpty ? customer.address : 'None',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (pendingOrder != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusDeliveredContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.successBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_rounded,
                                size: 18, color: AppColors.statusDelivered),
                            SizedBox(width: 6),
                            Text(
                              'Pending Plate Order Detected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusDelivered,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Plate: ${pendingOrder['plateNumber'] ?? 'N/A'}\nSpecs: ${pendingOrder['plateSpecs'] ?? 'N/A'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.successDeep),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text(
                          'No pending custom plate orders.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.navyMuted),
                        ),
                      ],
                    ),
                  ),
                if (lastParcel != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tealContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.tealAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppColors.navyPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Last Courier: ${lastParcel.platform} (${lastParcel.courier})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navyPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side:
                              const BorderSide(color: AppColors.textSecondary),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _finishScan();
                        },
                        child: const Text(
                          'Scan Again',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, {
                            'customer': customer,
                            'lastParcel': lastParcel,
                            'pendingOrder': pendingOrder,
                            'pendingOrderId': pendingOrderId,
                          });
                        },
                        child: const Text(
                          'Auto-Fill Dispatch',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Customer QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Toggle Flashlight',
            icon: Icon(
              _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchEnabled ? AppColors.statusPending : Colors.white,
            ),
            onPressed: () async {
              if (_isDisposed) return;
              try {
                await _scannerController.toggleTorch();
                if (mounted) setState(() => _torchEnabled = !_torchEnabled);
              } catch (_) {
                // Torch is unavailable until the camera has started.
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_isProcessing) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  _handleBarcode(value);
                  break;
                }
              }
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.logoBlue, width: 3),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.logoBlue.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 10,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _manualSearchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter code manually (e.g. GJAS1:...)...',
                          hintStyle: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _handleBarcode(value.trim());
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.navyPrimary),
                      onPressed: () {
                        if (_manualSearchCtrl.text.trim().isNotEmpty) {
                          _handleBarcode(_manualSearchCtrl.text.trim());
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
