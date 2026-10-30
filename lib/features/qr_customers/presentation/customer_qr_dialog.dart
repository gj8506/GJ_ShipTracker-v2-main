import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/customer_model.dart';

class CustomerQrDialog extends StatelessWidget {
  final CustomerModel customer;

  const CustomerQrDialog({super.key, required this.customer});

  void _shareQrCode() {
    Share.share(
      'GJandAsher Customer QR: ${customer.name}\nCustomer Code: ${customer.qrPayload}\nType: ${customer.type.toUpperCase()}',
      subject: 'GJandAsher Customer ID Card',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GJandAsher ID Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                    Text(
                      customer.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: customer.type == 'reseller'
                            ? AppColors.tealAccent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // QR Code Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: QrImageView(
                data: customer.qrPayload,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.navyPrimary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navyPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Details
            Text(
              customer.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              customer.contactNumber.isNotEmpty
                  ? customer.contactNumber
                  : 'No contact provided',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tealContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CODE: ${customer.qrPayload}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tealDark,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Share Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _shareQrCode,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Customer Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
