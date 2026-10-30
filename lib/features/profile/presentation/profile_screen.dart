import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../auth/presentation/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.statusReturned, // Soft red matching design
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PrivacyPolicySheet(),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String? currentPhone,
    String uid,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ref.read(authRepositoryProvider).updateProfile(
                      uid: uid,
                      displayName: nameCtrl.text.trim(),
                      phoneNumber: phoneCtrl.text.trim().isNotEmpty
                          ? phoneCtrl.text.trim()
                          : null,
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.statusReturned),
            tooltip: 'Sign Out',
            onPressed: () => _handleSignOut(context, ref),
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No user profile found'));
          }

          final roleColor =
              profile.isAdmin ? AppColors.navyPrimary : AppColors.tealDark;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    AppAvatar(
                      displayName: profile.displayName,
                      photoUrl: profile.photoUrl,
                      radius: 36,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.tealDark,
                          ),
                          onPressed: () {
                            _showEditProfileDialog(
                              context,
                              ref,
                              profile.displayName,
                              profile.phoneNumber,
                              profile.uid,
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.role.toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Module 4 & 11 Quick Actions: Customers, Scanner, and Inbox
              const Text(
                'Customer & Support Management',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.qr_code_2_rounded,
                          color: AppColors.tealDark),
                      title: const Text('Customer & Reseller QR Directory'),
                      subtitle: const Text(
                          'Manage repeat customers and custom QR codes'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile/customers'),
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.shopeeOrange),
                      title: const Text('Scan Reseller QR Code'),
                      subtitle: const Text(
                          'Instant autofill for outbound dispatches'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile/reseller-scanner'),
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded,
                          color: AppColors.statusInTransit),
                      title: const Text('Customer Support Inbox'),
                      subtitle:
                          const Text('Handle defect reports and inquiries'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile/support-inbox'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // System & Legal Section
              const Text(
                'App & Compliance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.navyPrimary),
                  title: const Text('Privacy Policy & Terms',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      const Text('Data Privacy Act (RA 10173) & shop terms'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ),
              const SizedBox(height: 28),

              // Sign Out Outlined Button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusReturned,
                    side: const BorderSide(
                        color: AppColors.dangerBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () => _handleSignOut(context, ref),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// DPA & Terms Bottom Sheet (Read-Only version for Staff/Admin Profile)
class _PrivacyPolicySheet extends StatelessWidget {
  const _PrivacyPolicySheet();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Terms of Service & Data Privacy Act (RA 10173)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyPrimary),
            ),
          ),
          const Divider(height: 32),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                '''DATA PRIVACY CONSENT & COMPLIANCE
Pursuant to the Data Privacy Act of 2012 (Republic Act No. 10173), GJandAsher ShipTracker enforces organizational, technical, and physical security measures to protect outbound customer data, dispatch manifests, return logs, and sales metrics.

1. INTERNAL DATA USAGE
Staff and Admin personnel are granted role-based access strictly to process motorcycle plate dispatches, manage courier tracking, handle defect logs, and consult analytics.

2. CONFIDENTIALITY OBLIGATION
Customer addresses, phone numbers, and custom plate details are strictly confidential and must not be exported, disclosed, or shared with unauthorized third parties outside of assigned standard couriers (Shopee, Lazada, TikTok Shop, J&T, SPX, Flash).

3. AUDIT TRAILS & INTEGRITY
All dispatch actions, status updates, and returns logged are stamped with staff user credentials for administrative audit trails.

4. USER RIGHTS
Data subjects retain all rights guaranteed under RA 10173, including access, correction, and account deletion requests via administration.''',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textPrimary, height: 1.6),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
