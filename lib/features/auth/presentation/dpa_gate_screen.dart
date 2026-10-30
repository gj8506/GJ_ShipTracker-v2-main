import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/dpa_service.dart';
import '../../../core/theme/app_colors.dart';

class DpaGateScreen extends ConsumerStatefulWidget {
  const DpaGateScreen({super.key});

  @override
  ConsumerState<DpaGateScreen> createState() => _DpaGateScreenState();
}

class _DpaGateScreenState extends ConsumerState<DpaGateScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onAccept() async {
    await ref.read(dpaServiceProvider).acceptPolicy();
    ref.invalidate(dpaAcceptedStatusProvider);
    if (mounted) {
      context.go('/login');
    }
  }

  void _onDecline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Consent Required'),
        content: const Text(
          'In accordance with Republic Act No. 10173 (Data Privacy Act of 2012), '
          'G.J. & Asher ShipTracker requires your consent to securely process your shipping, '
          'order, and identity records. Without consent, the application cannot proceed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Review Again'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              if (Platform.isAndroid || Platform.isIOS) {
                SystemNavigator.pop();
              } else {
                exit(0);
              }
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Privacy Agreement'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Republic Act No. 10173',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Philippine Data Privacy Act (DPA)',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Information We Collect',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'We collect personal and transactional information including your full name, contact numbers, delivery addresses, plate customization details, and parcel tracking numbers.',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '2. Purpose of Processing',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your data is collected strictly to fulfill parcel deliveries, custom plate manufacturing, customer support verification, and reseller QR code scanning in accordance with our operations.',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '3. Security & Storage',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All information is stored in encrypted cloud databases protected by role-based security rules. We do not sell or lease personal data to any external marketing entities.',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '4. Your Rights Under RA 10173',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'As a Data Subject, you have the right to be informed, access, rectify, object, or request deletion of your records subject to ongoing transactional compliance.',
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Policy Version: $kDpaPolicyVersion.0 • Effective 2026',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Accept & Continue'),
                    ),
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
