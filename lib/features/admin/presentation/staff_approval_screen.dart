import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/email_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/user_profile_model.dart';
import '../../auth/presentation/auth_providers.dart';
import 'staff_approval_providers.dart';

class StaffApprovalScreen extends ConsumerStatefulWidget {
  const StaffApprovalScreen({super.key});

  @override
  ConsumerState<StaffApprovalScreen> createState() =>
      _StaffApprovalScreenState();
}

class _StaffApprovalScreenState extends ConsumerState<StaffApprovalScreen> {
  String? _processingUid;

  Future<void> _approve(UserProfileModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Approve staff account?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${staff.fullName} (${staff.email}) will be able to sign in to the '
          'Staff Portal immediately. An approval email will be sent to the '
          'address above.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDelivered,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final adminUid = ref.read(currentUserProvider)?.uid ?? '';
    setState(() => _processingUid = staff.uid);

    try {
      final result = await ref
          .read(staffApprovalRepositoryProvider)
          .approveStaff(staff: staff, adminUid: adminUid);

      if (!mounted) return;

      if (result.emailSent) {
        _showMessage(
          '${staff.fullName} approved. Approval email sent to ${staff.email}.',
          color: AppColors.statusDelivered,
        );
      } else {
        _showMessage(
          '${staff.fullName} approved, but the email could not be sent. '
          'Check the email worker configuration.',
          color: AppColors.warningOrange,
          action: SnackBarAction(
            label: 'Retry email',
            textColor: Colors.white,
            onPressed: () => _resendEmail(staff),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not approve ${staff.fullName}: $e',
          color: AppColors.errorRed,
        );
      }
    } finally {
      if (mounted) setState(() => _processingUid = null);
    }
  }

  Future<void> _resendEmail(UserProfileModel staff) async {
    final result = await ref
        .read(staffApprovalRepositoryProvider)
        .resendApprovalEmail(staff);

    if (!mounted) return;

    if (result.emailSent) {
      _showMessage(
        'Approval email re-sent to ${staff.email}.',
        color: AppColors.statusDelivered,
      );
    } else {
      _showMessage(
        'Email still failed: ${result.emailError ?? 'Unknown error'}',
        color: AppColors.errorRed,
      );
    }
  }

  Future<void> _reject(UserProfileModel staff) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject staff account?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${staff.fullName} will not be able to sign in to the Staff '
              'Portal. You can optionally include a reason for your records.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonCtrl.dispose();
      return;
    }

    final adminUid = ref.read(currentUserProvider)?.uid ?? '';
    setState(() => _processingUid = staff.uid);

    try {
      await ref.read(staffApprovalRepositoryProvider).rejectStaff(
            staff: staff,
            adminUid: adminUid,
            reason: reasonCtrl.text,
          );
      if (mounted) {
        _showMessage(
          '${staff.fullName}\'s registration was rejected.',
          color: AppColors.errorRed,
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not reject ${staff.fullName}: $e',
          color: AppColors.errorRed,
        );
      }
    } finally {
      reasonCtrl.dispose();
      if (mounted) setState(() => _processingUid = null);
    }
  }

  void _showMessage(
    String message, {
    required Color color,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        action: action,
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Staff Approvals'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only the owner/admin can review staff registrations.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pendingAsync = ref.watch(pendingStaffProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Staff Approvals'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          error: err,
          onRetry: () => ref.invalidate(pendingStaffProvider),
        ),
        data: (staff) {
          if (staff.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingStaffProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (!EmailService().isConfigured) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.mark_email_unread_outlined,
                            color: AppColors.warningStrong),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Approval emails are disabled in this build. '
                            'Rebuild with EMAIL_WORKER_URL and EMAIL_API_KEY '
                            'to send the approval email automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.warningDeep,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.tealBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.infoBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${staff.length} staff registration'
                          '${staff.length == 1 ? '' : 's'} waiting for review. '
                          'Approving sends an email to the staff member.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.navySecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final member in staff) ...[
                  _StaffCard(
                    staff: member,
                    initials: _initials(member.fullName),
                    requestedAt: _formatDate(member.createdAt),
                    isProcessing: _processingUid == member.uid,
                    onApprove: () => _approve(member),
                    onReject: () => _reject(member),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final UserProfileModel staff;
  final String initials;
  final String requestedAt;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _StaffCard({
    required this.staff,
    required this.initials,
    required this.requestedAt,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.warningSurface,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.warningStrong,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.fullName.isEmpty ? 'Unnamed staff' : staff.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.navyMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: Text(
                        'PENDING • ${staff.role.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningStrong,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.phone_outlined,
            text: (staff.phoneNumber ?? '').trim().isEmpty
                ? 'No phone number provided'
                : staff.phoneNumber!,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: 'Requested $requestedAt',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.dangerBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusDelivered,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing ? null : onApprove,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(isProcessing ? 'Working...' : 'Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.navyMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.navyMuted),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  bool get _isPermissionDenied =>
      error.toString().toLowerCase().contains('permission-denied');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.statusReturnedContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 38,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load pending staff registrations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isPermissionDenied
                  ? 'Your account is not allowed to read the staff list. Ask '
                      'the owner to deploy the latest Firestore rules, and make '
                      'sure your profile role is "admin".'
                  : error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.navyMuted),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.statusDeliveredContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 44,
                color: AppColors.statusDelivered,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No pending staff registrations',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'New staff sign-ups will appear here for your review.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.navyMuted),
            ),
          ],
        ),
      ),
    );
  }
}
