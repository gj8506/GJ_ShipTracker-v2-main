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

  Future<void> _onAccept() async {
    // Accept the version that is live right now, not a hard-coded constant.
    final policy =
        ref.read(dpaPolicyProvider).value ?? DpaPolicy.defaults;
    await ref.read(dpaServiceProvider).acceptPolicy(policy.version);
    ref.invalidate(dpaAcceptedStatusProvider);
    // Wait for the provider to report the new value before navigating, so the
    // router cannot see a loading gate and bounce the user back here.
    await ref.read(dpaAcceptedStatusProvider.future);
    if (mounted) {
      // The router decides the portal: logged-out users go to /login, signed-in
      // owners/staff to the Admin Dashboard and buyers to the Customer UI.
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
    // Streams the admin-edited policy; falls back to the seed text while the
    // document loads or when the device is offline.
    final policy = ref.watch(dpaPolicyProvider).value ?? DpaPolicy.defaults;

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
                    child: Icon(Icons.privacy_tip_outlined,
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
                        Text(policy.title,
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
                          policy.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Policy Version: ${policy.version}.0 • ${policy.updatedLabel}',
                            textAlign: TextAlign.center,
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
