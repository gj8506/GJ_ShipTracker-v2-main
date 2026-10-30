import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/parcel_model.dart';
import 'parcel_providers.dart';

class ParcelDetailScreen extends ConsumerWidget {
  final String parcelId;

  const ParcelDetailScreen({super.key, required this.parcelId});

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusDispatched:
        return AppColors.statusDispatched;
      case AppConstants.statusInTransit:
        return AppColors.statusInTransit;
      case AppConstants.statusDelivered:
        return AppColors.statusDelivered;
      case AppConstants.statusReturned:
        return AppColors.statusReturned;
      case AppConstants.statusCancelled:
        return AppColors.statusCancelled;
      default:
        return AppColors.statusPending;
    }
  }

  void _showStatusBottomSheet(
      BuildContext context, WidgetRef ref, ParcelModel parcel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Delivery Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // Scrollable Status List (Eliminates bottom overflow completely!)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: AppConstants.parcelStatuses.map((status) {
                      final isSelected = parcel.status == status;
                      final statusColor = _getStatusColor(status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? statusColor.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? statusColor
                                : AppColors.borderLight,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            status,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? statusColor
                                  : AppColors.navyPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: statusColor, size: 20)
                              : null,
                          onTap: () async {
                            final user = ref.read(userProfileProvider).value;
                            await ref
                                .read(parcelRepositoryProvider)
                                .updateParcelStatus(
                                  parcel.id,
                                  status,
                                  dispatchedById: user?.uid,
                                  dispatchedByName: user?.displayName,
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelAsync = ref.watch(singleParcelStreamProvider(parcelId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Parcel Details')),
      body: parcelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading parcel: $err',
                style: const TextStyle(color: AppColors.statusReturned)),
          ),
        ),
        data: (parcel) {
          if (parcel == null) {
            return const Center(child: Text('Parcel not found.'));
          }

          final statusColor = _getStatusColor(parcel.status);
          final formattedDate =
              DateFormat('MMM dd, yyyy • hh:mm a').format(parcel.createdAt);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Tracking & Status Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          parcel.platform.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            parcel.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Tracking Number',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            parcel.trackingNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.navyPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 20, color: AppColors.tealDark),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: parcel.trackingNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Tracking number copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Courier',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                        Text(
                          parcel.courier,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Customer & Delivery Info Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer & Delivery Information',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyPrimary),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(Icons.person_outline_rounded, 'Recipient',
                        parcel.customerName),
                    if (parcel.contactNumber != null &&
                        parcel.contactNumber!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.phone_outlined, 'Contact',
                          parcel.contactNumber!),
                    ],
                    if (parcel.address != null &&
                        parcel.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.location_on_outlined, 'Address',
                          parcel.address!),
                    ],
                    if (parcel.items != null && parcel.items!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.two_wheeler_rounded, 'Custom Plates',
                          parcel.items!),
                    ],
                    const Divider(height: 24, color: AppColors.borderLight),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Declared Amount',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                        Text(
                          '₱${parcel.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tealDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Dispatch Audit Log Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timeline & Dispatch Details',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyPrimary),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Created Date',
                        formattedDate),
                    if (parcel.dispatchedByName != null) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.badge_outlined, 'Dispatched By',
                          parcel.dispatchedByName!),
                    ],
                    if (parcel.notes != null && parcel.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(
                          Icons.note_alt_outlined, 'Notes', parcel.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Update Status Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text(
                    'Change Parcel Status',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showStatusBottomSheet(context, ref, parcel),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navyPrimary),
          ),
        ),
      ],
    );
  }
}
