import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import 'create_return_screen.dart';
import 'returns_providers.dart';

class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  static const List<String> _statusOptions = [
    'Pending',
    'Approved',
    'Replacement Dispatched',
    'Refunded',
    'Rejected',
  ];

  Color _getReturnStatusColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'approved' ||
        s == AppConstants.returnStatusApproved.toLowerCase()) {
      return AppColors.statusDelivered;
    } else if (s == 'replacement dispatched' ||
        s == AppConstants.returnStatusReplacementDispatched.toLowerCase() ||
        s.contains('dispatched')) {
      return AppColors.statusDispatched;
    } else if (s == 'refunded' ||
        s == AppConstants.returnStatusRefunded.toLowerCase() ||
        s.contains('refund')) {
      return AppColors.tealDark;
    } else if (s == 'rejected' ||
        s == AppConstants.returnStatusRejected.toLowerCase() ||
        s.contains('reject')) {
      return AppColors.statusReturned;
    }
    return AppColors.statusPending;
  }

  IconData _getReturnStatusIcon(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'approved' ||
        s == AppConstants.returnStatusApproved.toLowerCase()) {
      return Icons.check_circle_outline_rounded;
    } else if (s == 'replacement dispatched' || s.contains('dispatched')) {
      return Icons.local_shipping_outlined;
    } else if (s == 'refunded' || s.contains('refund')) {
      return Icons.currency_exchange_rounded;
    } else if (s == 'rejected' || s.contains('reject')) {
      return Icons.cancel_outlined;
    }
    return Icons.pending_actions_rounded;
  }

  void _openCreateReturnScreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CreateReturnScreen()),
    );
  }

  /// Full-Screen Interactive Photo Viewer Dialog (With Auto-Disposing PageController)
  void _showImagePreviewDialog(
      BuildContext context, List<String> photoUrls, int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        int currentIndex = initialIndex;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Stack(
              children: [
                // Image Carousel with Pinch-to-Zoom
                PageView.builder(
                  controller: pageController,
                  itemCount: photoUrls.length,
                  onPageChanged: (index) {
                    setDialogState(() => currentIndex = index);
                  },
                  itemBuilder: (context, idx) {
                    final url = photoUrls[idx];
                    return Center(
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.navyDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_rounded,
                                      size: 48, color: Colors.white54),
                                  SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Top Bar: Counter & Close Button
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (photoUrls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${photoUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 24),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),

                // Bottom Hint
                const Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Pinch to zoom • Swipe to view more',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => pageController.dispose());
  }

  void _showUpdateStatusDialog(
      BuildContext context, WidgetRef ref, ReturnModel item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _UpdateStatusDialog(
        item: item,
        statusOptions: _statusOptions,
        getStatusColor: _getReturnStatusColor,
        getStatusIcon: _getReturnStatusIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsStreamProvider);
    final filteredReturns = ref.watch(filteredReturnsProvider);
    final selectedDefect = ref.watch(selectedDefectFilterProvider);

    // Live counts
    final allReturns = returnsAsync.value ?? [];
    final pendingCount = allReturns.where((r) {
      final s = r.status.trim().toLowerCase();
      return s == 'pending';
    }).length;

    final resolvedCount = allReturns.where((r) {
      final s = r.status.trim().toLowerCase();
      return s != 'pending';
    }).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Returns & Defect Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Returns Log',
            onPressed: () {
              ref.invalidate(returnsStreamProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Returns log refreshed'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Primary action: kept inline (instead of a FAB) so it never
          // collides with the global chatbot FAB.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openCreateReturnScreen(context),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                label: const Text('Log Return Ticket'),
              ),
            ),
          ),

          // Top Counters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Tickets',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$pendingCount',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusPending,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resolved / Closed',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$resolvedCount',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusDelivered,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (val) =>
                  ref.read(returnSearchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search tracking number, customer, defect...',
                hintStyle: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),

          // Defect Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Defects'),
                  selected: selectedDefect == null,
                  onSelected: (_) => ref
                      .read(selectedDefectFilterProvider.notifier)
                      .state = null,
                  selectedColor: AppColors.navyPrimary,
                  labelStyle: TextStyle(
                    color: selectedDefect == null
                        ? Colors.white
                        : AppColors.navyPrimary,
                    fontWeight: selectedDefect == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selectedDefect == null
                        ? AppColors.navyPrimary
                        : AppColors.borderLight,
                  ),
                ),
                const SizedBox(width: 8),
                ...AppConstants.returnDefectReasons.map((defect) {
                  final isSelected = selectedDefect == defect;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(defect),
                      selected: isSelected,
                      onSelected: (_) => ref
                          .read(selectedDefectFilterProvider.notifier)
                          .state = isSelected ? null : defect,
                      selectedColor: AppColors.navyPrimary,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.navyPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.navyPrimary
                            : AppColors.borderLight,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Returns List
          Expanded(
            child: returnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading returns: $err',
                      style: const TextStyle(color: AppColors.statusReturned)),
                ),
              ),
              data: (_) {
                if (filteredReturns.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 60, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No return tickets found',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap "Log Return Ticket" above to record a defect or return.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: filteredReturns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredReturns[index];
                    final statusColor = _getReturnStatusColor(item.status);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tracking Number & Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.trackingNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          statusColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  item.status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Platform & Resolution tags
                          Row(
                            children: [
                              if (item.platform.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.platform,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.navyMuted),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (item.resolutionType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusInTransitContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.resolutionType,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.statusInTransit,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Customer Info
                          if (item.customerName.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.customerName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Defect Reason Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.statusReturnedContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.dangerDeep),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    item.defectReason,
                                    style: const TextStyle(
                                      color: AppColors.dangerDeep,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Notes
                          if (item.notes != null &&
                              item.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.notes!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],

                          // Replacement Tracking #
                          if (item.replacementTrackingNumber != null &&
                              item.replacementTrackingNumber!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined,
                                    size: 14,
                                    color: AppColors.statusDispatched),
                                const SizedBox(width: 6),
                                Text(
                                  'Replacement: ${item.replacementTrackingNumber!}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusDispatched,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Photo Evidence Gallery (Clickable)
                          if (item.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                    size: 14, color: AppColors.navyPrimary),
                                const SizedBox(width: 5),
                                Text(
                                  'Photo Evidence (${item.photoUrls.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.navyPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '• Tap to preview',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 68,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: item.photoUrls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, photoIndex) {
                                  final photoUrl = item.photoUrls[photoIndex];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _showImagePreviewDialog(
                                      context,
                                      item.photoUrls,
                                      photoIndex,
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.network(
                                            photoUrl,
                                            width: 68,
                                            height: 68,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return Container(
                                                width: 68,
                                                height: 68,
                                                color: AppColors.surfaceMuted,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  size: 22,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.fullscreen_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const Divider(
                              height: 20, color: AppColors.borderLight),

                          // Bottom Row: Date & Update Status Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Logged: ${item.createdAt.month}/${item.createdAt.day}/${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.navyPrimary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                    Icons.playlist_add_check_rounded,
                                    size: 18),
                                label: const Text(
                                  'Update Status',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: () =>
                                    _showUpdateStatusDialog(context, ref, item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Stateful Dialog Widget:
/// Eliminates '_dependents.isEmpty: is not true' by properly managing focus and controller lifecycles.
class _UpdateStatusDialog extends ConsumerStatefulWidget {
  final ReturnModel item;
  final List<String> statusOptions;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;

  const _UpdateStatusDialog({
    required this.item,
    required this.statusOptions,
    required this.getStatusColor,
    required this.getStatusIcon,
  });

  @override
  ConsumerState<_UpdateStatusDialog> createState() =>
      _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends ConsumerState<_UpdateStatusDialog> {
  late String _selectedStatus;
  late final TextEditingController _replacementTrackingCtrl;
  late final FocusNode _replacementFocusNode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.statusOptions.firstWhere(
      (s) => s.toLowerCase() == widget.item.status.trim().toLowerCase(),
      orElse: () => 'Pending',
    );
    _replacementTrackingCtrl = TextEditingController(
      text: widget.item.replacementTrackingNumber ?? '',
    );
    _replacementFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _replacementTrackingCtrl.dispose();
    _replacementFocusNode.dispose();
    super.dispose();
  }

  void _handleCancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  Future<void> _handleSaveStatus() async {
    // 1. Remove keyboard focus cleanly first to prevent assertion failure
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final user = ref.read(userProfileProvider).value;
    final newTracking = _replacementTrackingCtrl.text.trim();

    try {
      await ref.read(returnsRepositoryProvider).updateReturnStatus(
            id: widget.item.id,
            status: _selectedStatus,
            replacementTrackingNumber: newTracking,
            handledById: user?.uid,
            handledByName: user?.displayName,
          );
    } catch (_) {
      try {
        await FirebaseFirestore.instance
            .collection('returns')
            .doc(widget.item.id)
            .update({
          'status': _selectedStatus,
          if (_selectedStatus == 'Replacement Dispatched' ||
              _selectedStatus == AppConstants.returnStatusReplacementDispatched)
            'replacementTrackingNumber': newTracking,
          'handledById': user?.uid,
          'handledByName': user?.displayName ?? 'Staff',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating status: $e');
      }
    }

    ref.invalidate(returnsStreamProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to "$_selectedStatus"'),
          backgroundColor: AppColors.navyPrimary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.navyPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rule_rounded,
                color: AppColors.navyPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Update Return Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket: ${widget.item.trackingNumber}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select new status:',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              // 5 Clean Status Option Cards
              ...widget.statusOptions.map((status) {
                final isSelected =
                    _selectedStatus.toLowerCase() == status.toLowerCase();
                final color = widget.getStatusColor(status);
                final icon = widget.getStatusIcon(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _selectedStatus = status);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.12)
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : AppColors.borderLight,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color:
                                    isSelected ? color : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 20)
                          else
                            const Icon(Icons.radio_button_unchecked_rounded,
                                color: AppColors.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Replacement Tracking input appears when 'Replacement Dispatched' is selected
              if (_selectedStatus == 'Replacement Dispatched' ||
                  _selectedStatus ==
                      AppConstants.returnStatusReplacementDispatched) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _replacementTrackingCtrl,
                  focusNode: _replacementFocusNode,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'New Replacement Tracking #',
                    hintText: 'e.g. SPX99887766',
                    prefixIcon: const Icon(Icons.local_shipping_outlined,
                        color: AppColors.navyPrimary, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSaving ? null : _handleCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isSaving ? null : _handleSaveStatus,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Status'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
