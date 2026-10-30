import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: Required for input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../parcels/domain/parcel_model.dart';
import '../../parcels/presentation/parcel_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../qr_customers/domain/customer_model.dart';
import '../../qr_customers/presentation/reseller_scanner_screen.dart';
import '../../qr_customers/presentation/customer_list_screen.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trackingController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _itemsController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPlatform = AppConstants.platformShopee;
  String _selectedCourier = AppConstants.supportedCouriers.first;
  bool _isLoading = false;

  String? _pendingOrderId;
  String? _scannedCustomerId;

  @override
  void dispose() {
    _trackingController.dispose();
    _customerNameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openCustomerQrScanner() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const ResellerScannerScreen()),
    );

    if (result != null) {
      final customer = result['customer'] as CustomerModel;
      final lastParcel = result['lastParcel'] as ParcelModel?;
      final pendingOrder = result['pendingOrder'] as Map<String, dynamic>?;
      final pendingOrderId = result['pendingOrderId'] as String?;

      setState(() {
        _scannedCustomerId = customer.id;
        _customerNameController.text =
            pendingOrder?['customerName'] ?? customer.name;
        _contactController.text =
            pendingOrder?['contactNumber'] ?? customer.contactNumber;
        _addressController.text =
            pendingOrder?['deliveryAddress'] ?? customer.address;

        if (lastParcel != null) {
          _selectedPlatform = lastParcel.platform;
          _selectedCourier = lastParcel.courier;
        }

        if (pendingOrder != null) {
          _itemsController.text =
              'Custom Plate: [${pendingOrder['plateNumber']}] ${pendingOrder['plateSpecs']}';
          _notesController.text = pendingOrder['specialNotes'] ?? '';
          _pendingOrderId = pendingOrderId;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pendingOrder != null
                ? 'Auto-filled pending order for ${customer.name}!'
                : 'Auto-filled customer details for ${customer.name}!'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
      }
    }
  }

  Future<void> _submitDispatch() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to dispatch parcels.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProfile = ref.read(userProfileProvider).value;
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final newParcel = ParcelModel(
        trackingNumber: _trackingController.text.trim(),
        platform: _selectedPlatform,
        courier: _selectedCourier,
        customerId: _scannedCustomerId,
        customerName: _customerNameController.text.trim(),
        contactNumber: _contactController.text.trim(),
        address: _addressController.text.trim(),
        items: _itemsController.text.trim(),
        amount: amount,
        notes: _notesController.text.trim(),
        status: AppConstants.statusDispatched,
        dispatchedById: user.uid,
        dispatchedByName: userProfile?.displayName ?? 'Staff User',
        dispatchedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await ref.read(parcelRepositoryProvider).addParcel(newParcel);

      if (_pendingOrderId != null) {
        await FirebaseFirestore.instance
            .collection('order_requests')
            .doc(_pendingOrderId)
            .update({
          'status': 'DISPATCHED',
          'finalAmount': amount,
          'trackingNumber': _trackingController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Parcel ${newParcel.trackingNumber} dispatched successfully!'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error dispatching parcel: $e'),
              backgroundColor: AppColors.statusReturned),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _trackingController.clear();
    _customerNameController.clear();
    _contactController.clear();
    _addressController.clear();
    _itemsController.clear();
    _amountController.clear();
    _notesController.clear();
    setState(() {
      _selectedPlatform = AppConstants.platformShopee;
      _selectedCourier = AppConstants.supportedCouriers.first;
      _pendingOrderId = null;
      _scannedCustomerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Outbound Dispatch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCustomerQrScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.tealAccent),
                      label: const Text(
                        'Scan QR (Check Plate Orders)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.tealAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.people_outline_rounded,
                        color: AppColors.navyPrimary),
                    tooltip: 'Customer Registry',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CustomerListScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Platform',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.navyMuted,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: AppConstants.allPlatforms.map((platform) {
                    final isSelected = _selectedPlatform == platform;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                        label: Text(platform),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedPlatform = platform),
                        selectedColor: AppColors.navyPrimary,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.navyPrimary
                                : AppColors.borderLight,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : AppColors.navyPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trackingController,
                // ADDED: Limit tracking number to exactly 15 characters
                inputFormatters: [
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(
                  labelText: 'Tracking Number *',
                  hintText: 'e.g. SPX4572829R9E8',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _trackingController.clear(),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter tracking number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourier,
                decoration: const InputDecoration(
                  labelText: 'Assigned Courier *',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: AppConstants.supportedCouriers.map((courier) {
                  return DropdownMenuItem(value: courier, child: Text(courier));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCourier = val!),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter name'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Final Amount (₱) *',
                        prefixText: '₱ ',
                        hintText: '0.00',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter amount'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                // ADDED: Block letters/symbols and cap at 11 digits
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _itemsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Items / Plate Specs',
                  hintText: 'e.g. 2x Side Mirror, Custom Plate',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Order Notes (Optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitDispatch,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isLoading ? 'Dispatching...' : 'Dispatch Parcel',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
