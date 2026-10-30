import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PrivacyPolicySheet extends StatelessWidget {
  const PrivacyPolicySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacyPolicySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.security_rounded,
                  color: AppColors.tealAccent, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data Privacy Act Consent Notice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'In compliance with Republic Act No. 10173 (Data Privacy Act of 2012)',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const Divider(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    '1. Purpose of Data Processing',
                    'GJandAsher ShipTracker collects staff user identity (Google display name and email address) exclusively to authenticate and attribute dispatch records, return logs, customer QR assignments, and internal operational actions within the business system.',
                  ),
                  _buildSection(
                    '2. Outbound Logistics & Customer Data',
                    'Customer shipping details (names, contact numbers, and delivery addresses) encoded via Shopee, Lazada, and TikTok Shop parcel tracking are processed solely for package fulfillment, courier coordination, defect resolution, and business analytics.',
                  ),
                  _buildSection(
                    '3. Storage, Confidentiality, & Role Security',
                    'All logistics records are stored securely in Google Cloud Firestore with strict role-based access rules. Staff members can execute daily dispatches and return logs, while financial analytics and forecasts remain restricted to Business Owners/Admins. Your consent timestamp is stored upon authentication.',
                  ),
                  _buildSection(
                    '4. Data Subject Rights',
                    'Under RA 10173, authorized users maintain the right to access, rectify, or request erasure of personal data not required by tax or commercial bookkeeping regulations. Direct inquiries may be addressed to the Business Administrator.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('I Understand & Agree',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.navyPrimary)),
          const SizedBox(height: 4),
          Text(content,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
