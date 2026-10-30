import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/irregular_hexagon_clipper.dart';

class OrderRequestFormScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOrderSubmitted;

  const OrderRequestFormScreen({super.key, this.onOrderSubmitted});

  @override
  ConsumerState<OrderRequestFormScreen> createState() =>
      _OrderRequestFormScreenState();
}

class _OrderRequestFormScreenState
    extends ConsumerState<OrderRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Field Controllers
  final _plateNumberCtrl = TextEditingController(text: 'M221NH');
  final _regionCtrl = TextEditingController(text: 'REGION 12');
  final _brandCtrl = TextEditingController(text: 'HONDA');
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Style Options
  static const List<String> _plateStyles = [
    'Standard',
    'Large',
    'Irregular Hexagon',
  ];
  String _selectedStyle = 'Irregular Hexagon';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(userProfileProvider).value;
      if (userProfile != null) {
        if (_fullNameCtrl.text.isEmpty) {
          _fullNameCtrl.text = userProfile.displayName;
        }
        if (_phoneCtrl.text.isEmpty && userProfile.phoneNumber != null) {
          _phoneCtrl.text = userProfile.phoneNumber!;
        }
      }
    });
  }

  @override
  void dispose() {
    _plateNumberCtrl.dispose();
    _regionCtrl.dispose();
    _brandCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrderRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a plate order request.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final plateSpecSummary =
          '${_selectedStyle.toUpperCase()} | Reg: ${_regionCtrl.text.trim()} | Make: ${_brandCtrl.text.trim().toUpperCase()}';

      await FirebaseFirestore.instance.collection('order_requests').add({
        'userId': user.uid,
        'customerName': _fullNameCtrl.text.trim(),
        'contactNumber': _phoneCtrl.text.trim(),
        'deliveryAddress': _addressCtrl.text.trim(),
        'plateNumber': _plateNumberCtrl.text.trim().toUpperCase(),
        'plateStyle': _selectedStyle,
        'region': _regionCtrl.text.trim().toUpperCase(),
        'brandMake': _brandCtrl.text.trim().toUpperCase(),
        'plateSpecs': plateSpecSummary,
        'specialNotes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'status': 'PENDING', // UPDATED: Matches 'My Orders' screen exactly
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Plate order request submitted! Awaiting staff review.'),
            backgroundColor: AppColors.tealDark,
          ),
        );

        if (widget.onOrderSubmitted != null) {
          widget.onOrderSubmitted!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit order: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'New Custom Plate Order',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Plate Visual Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildPlateVisualPreview(),
              const SizedBox(height: 20),
              _buildPlateSpecificationCard(),
              const SizedBox(height: 16),
              _buildRecipientCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitOrderRequest,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SUBMIT ORDER REQUEST',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlateVisualPreview() {
    final isHexagon = _selectedStyle == 'Irregular Hexagon';
    const plateWidth = double.infinity;
    final plateHeight = _selectedStyle == 'Large' ? 200.0 : 180.0;

    Widget innerPlate = Container(
      width: plateWidth,
      height: plateHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isHexagon ? null : BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyPrimary, width: 3.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.scrimLight,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMountSlot(),
              const Text(
                'REGISTERED',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: AppColors.navyPrimary,
                ),
              ),
              _buildMountSlot(),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _plateNumberCtrl.text.trim().isEmpty
                  ? 'ABC 1234'
                  : _plateNumberCtrl.text.trim().toUpperCase(),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                fontFamily: 'monospace',
                color: AppColors.navyPrimary,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _regionCtrl.text.trim().isEmpty
                    ? 'REGION 12'
                    : _regionCtrl.text.trim().toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.navyPrimary,
                ),
              ),
              Text(
                _brandCtrl.text.trim().isEmpty
                    ? 'MOTORCYCLE'
                    : _brandCtrl.text.trim().toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontStyle: FontStyle.italic,
                  color: AppColors.navyPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isHexagon) {
      return ClipPath(
        clipper: IrregularHexagonClipper(cutSize: 32),
        child: innerPlate,
      );
    }

    return innerPlate;
  }

  Widget _buildMountSlot() {
    return Container(
      width: 32,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textMuted, width: 1),
      ),
    );
  }

  Widget _buildPlateSpecificationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plate Specification',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _plateNumberCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Plate Number / Inscription *',
              hintText: 'e.g. M221NH or MV FILE #',
              prefixIcon:
                  const Icon(Icons.pin_outlined, color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter plate number' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedStyle,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Plate Shape / Style *',
              prefixIcon: const Icon(Icons.style_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _plateStyles
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedStyle = val);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Region *',
                    hintText: 'e.g. REGION 12, NCR',
                    prefixIcon: const Icon(Icons.map_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _brandCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Motorcycle Make *',
                    hintText: 'e.g. HONDA, YAMAHA',
                    prefixIcon: const Icon(Icons.two_wheeler_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recipient & Delivery Address',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter recipient name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Mobile Phone Number *',
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter contact number' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Complete Shipping Address *',
              hintText: 'Barangay, Municipality/City, Province',
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.location_on_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter delivery address'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: 'Special Notes / Conduction Details',
              hintText: 'e.g. Free bracket, hole spacing, or rush',
              prefixIcon:
                  const Icon(Icons.notes_rounded, color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
