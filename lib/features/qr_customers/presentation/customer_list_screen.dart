import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_providers.dart';
import 'customer_qr_dialog.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  void _showAddEditCustomerDialog(BuildContext context,
      [CustomerModel? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditCustomerDialog(existing: existing),
    );
  }

  // Smarter one-time sync function to prevent duplicates
  Future<void> _syncOldCustomers(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Get all users who have the customer role
      final usersSnap = await firestore
          .collection(AppConstants.collectionUsers)
          .where('role', isEqualTo: 'customer')
          .get();

      // 2. Get all existing customers to avoid duplicates
      final customersSnap = await firestore.collection('customers').get();

      // Map existing UIDs (FIXED: Removed unnecessary casts)
      final existingLinkedUids = customersSnap.docs
          .map((doc) => doc.data()['linkedUid'] as String?)
          .where((uid) => uid != null)
          .toSet();

      // Map existing Names (FIXED: Removed unnecessary casts)
      final existingNames = customersSnap.docs
          .map((doc) => (doc.data()['name'] as String?)?.toLowerCase().trim())
          .where((name) => name != null)
          .toSet();

      final batch = firestore.batch();
      int added = 0;

      // 3. Loop through users and add missing ones
      for (var doc in usersSnap.docs) {
        final data = doc.data();
        final uid = data['uid'] as String?;
        final name = data['fullName'] ?? data['displayName'] ?? 'Customer';
        final normalizedName = name.toString().toLowerCase().trim();

        // Only add if BOTH the UID and the Name are missing from the registry
        if (uid != null &&
            !existingLinkedUids.contains(uid) &&
            !existingNames.contains(normalizedName)) {
          final newDoc = firestore.collection('customers').doc();
          batch.set(newDoc, {
            'name': name,
            'contactNumber': data['phone'] ?? data['phoneNumber'] ?? '',
            'address': '',
            'type': 'regular',
            'linkedUid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          added++;
        }
      }

      if (added > 0) {
        await batch.commit();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully synced $added missing customer(s)!'),
              backgroundColor: AppColors.tealDark,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All customers are already synced.'),
              backgroundColor: AppColors.statusCancelled,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.statusReturned,
          ),
        );
      }
    }
  }

  Color _getBadgeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'reseller':
        return AppColors.tealContainer;
      case 'repeat':
        return AppColors.purpleContainer; // Soft purple
      case 'wholesale':
        return AppColors.statusPendingContainer; // Soft amber
      default:
        return AppColors.borderLight;
    }
  }

  Color _getBadgeTextColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'reseller':
        return AppColors.tealDark;
      case 'repeat':
        return AppColors.statusRefunded;
      case 'wholesale':
        return AppColors.warningDeep;
      default:
        return AppColors.navyMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final filteredCustomers = ref.watch(filteredCustomersProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Customer Registry & QR'),
        actions: [
          IconButton(
            tooltip: 'Sync Missing Accounts',
            icon: const Icon(Icons.sync_rounded, color: AppColors.navyPrimary),
            onPressed: () => _syncOldCustomers(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: () => _showAddEditCustomerDialog(context),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) =>
                  ref.read(customerSearchProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search by name, contact, shop...',
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

          // Content Area
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading customers: $err',
                    style: const TextStyle(color: AppColors.statusReturned),
                  ),
                ),
              ),
              data: (_) {
                if (filteredCustomers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppColors.tealContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.tealDark,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'No Customers Found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add repeat buyers or motorcycle shop resellers to generate custom QR codes for quick dispatching.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navyPrimary,
                              side: const BorderSide(
                                  color: AppColors.navyPrimary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Customer'),
                            onPressed: () =>
                                _showAddEditCustomerDialog(context),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredCustomers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    final isReseller =
                        customer.type.toLowerCase() == 'reseller';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Avatar Icon
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isReseller
                                  ? AppColors.tealContainer
                                  : AppColors.borderLight,
                              child: Icon(
                                isReseller
                                    ? Icons.storefront_rounded
                                    : Icons.person_rounded,
                                color: isReseller
                                    ? AppColors.tealDark
                                    : AppColors.navyPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Customer Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.navyPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _getBadgeColor(customer.type),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          customer.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getBadgeTextColor(
                                                customer.type),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customer.contactNumber.isNotEmpty
                                        ? customer.contactNumber
                                        : 'No contact provided',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.navyMuted),
                                  ),
                                  if (customer.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      customer.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMutedAlt),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // QR Dialog Button
                            IconButton(
                              icon: const Icon(Icons.qr_code_2_rounded,
                                  color: AppColors.tealDark, size: 26),
                              tooltip: 'View QR Code',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) =>
                                      CustomerQrDialog(customer: customer),
                                );
                              },
                            ),

                            // Edit Button
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.textSecondary, size: 20),
                              tooltip: 'Edit Customer',
                              onPressed: () =>
                                  _showAddEditCustomerDialog(context, customer),
                            ),
                          ],
                        ),
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

/// Dedicated, state-safe dialog that avoids the `_dependents.isEmpty` assertion error.
class _AddEditCustomerDialog extends ConsumerStatefulWidget {
  final CustomerModel? existing;

  const _AddEditCustomerDialog({this.existing});

  @override
  ConsumerState<_AddEditCustomerDialog> createState() =>
      _AddEditCustomerDialogState();
}

class _AddEditCustomerDialogState
    extends ConsumerState<_AddEditCustomerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _addressCtrl;
  late String _selectedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _contactCtrl =
        TextEditingController(text: widget.existing?.contactNumber ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');

    // Normalize type and ensure it matches one of the dropdown items
    final rawType = (widget.existing?.type ?? AppConstants.customerTypeRegular)
        .trim()
        .toLowerCase();
    const validTypes = ['regular', 'repeat', 'reseller', 'wholesale'];
    _selectedType = validTypes.contains(rawType) ? rawType : 'regular';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    final name = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if (name.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter name and contact number'),
          backgroundColor: AppColors.statusReturned,
        ),
      );
      return;
    }

    // Dismiss keyboard safely before executing async database work
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final model = CustomerModel(
        id: widget.existing?.id ?? '',
        name: name,
        contactNumber: contact,
        address: _addressCtrl.text.trim(),
        type: _selectedType,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      final repo = ref.read(customerRepositoryProvider);
      if (widget.existing == null) {
        await repo.addCustomer(model);
      } else {
        await repo.updateCustomer(model);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null
                  ? 'Customer added successfully!'
                  : 'Customer updated successfully!',
            ),
            backgroundColor: AppColors.tealDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving customer: $e'),
            backgroundColor: AppColors.statusReturned,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEditing ? 'Edit Customer' : 'Add New Customer / Reseller',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer / Motor Shop Name *',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactCtrl,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number *',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              enabled: !_isSaving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue:
                  _selectedType, // FIXED: Replaced 'value' with 'initialValue'
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Customer Category',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'regular', child: Text('Regular Customer')),
                DropdownMenuItem(
                    value: 'repeat', child: Text('Repeat Customer')),
                DropdownMenuItem(
                    value: 'reseller', child: Text('Reseller / Moto Shop')),
                DropdownMenuItem(
                    value: 'wholesale', child: Text('Wholesale Buyer')),
              ],
              onChanged: _isSaving
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _saveCustomer,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save Changes' : 'Save Customer'),
        ),
      ],
    );
  }
}
