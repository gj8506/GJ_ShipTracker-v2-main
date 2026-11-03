import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_validators.dart';
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
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressDetailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ---------------------------------------------------------------------
  // Plate styles and their estimated fixed prices.
  //
  // Edit [_plateStylePrices] when your rates change: the amount is written to
  // the order request as `price` / `estimatedPrice`.
  // ---------------------------------------------------------------------
  static const String _styleStandard = 'Standard (Irregular Hexagon)';
  static const String _styleLarge = 'Large';

  static const List<String> _plateStyles = [_styleStandard, _styleLarge];

  static const Map<String, double> _plateStylePrices = {
    _styleStandard: 1450.0,
    _styleLarge: 1950.0,
  };

  String _selectedStyle = _styleStandard;

  // ---------------------------------------------------------------------
  // Dropdown choices.
  // `_deliveryAreas` is the list of places you deliver to. Add or remove
  // entries to match your coverage; "Other" always falls back to a free-text
  // address so an order is never blocked.
  // ---------------------------------------------------------------------
  static const String _otherAreaOption = 'Other (type full address)';

  static const List<String> _deliveryAreas = [
    'Nagcarlan, Laguna',
    'Liliw, Laguna',
    'Magdalena, Laguna',
    'Majayjay, Laguna',
    'Rizal, Laguna',
    'San Pablo City, Laguna',
    'Calauan, Laguna',
    'Pila, Laguna',
    'Santa Cruz, Laguna',
    'Los Baños, Laguna',
    'Bay, Laguna',
    'Calamba, Laguna',
    'Metro Manila',
    'Batangas',
    'Cavite',
    'Quezon',
    _otherAreaOption,
  ];

  static const List<String> _regions = [
    'NCR',
    'CAR',
    'REGION 1',
    'REGION 2',
    'REGION 3',
    'REGION 4-A',
    'MIMAROPA',
    'REGION 5',
    'REGION 6',
    'REGION 7',
    'REGION 8',
    'REGION 9',
    'REGION 10',
    'REGION 11',
    'REGION 12',
    'REGION 13',
    'BARMM',
  ];

  static const List<String> _motorcycleMakes = [
    'HONDA',
    'YAMAHA',
    'SUZUKI',
    'KAWASAKI',
    'TVS',
    'KYMCO',
    'RUSI',
    'BAJAJ',
    'CFMOTO',
    'OTHER',
  ];

  String _selectedRegion = 'REGION 12';
  String _selectedMake = 'HONDA';
  String? _selectedArea;

  bool get _isOtherArea => _selectedArea == _otherAreaOption;

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
          _phoneCtrl.text = normalizeContactNumber(userProfile.phoneNumber);
        }
      }
    });
  }

  @override
  void dispose() {
    _plateNumberCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressDetailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrderRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to submit a plate order request.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final area = _selectedArea ?? '';
      final addressDetail = _addressDetailCtrl.text.trim();
      final deliveryAddress =
          area == _otherAreaOption ? addressDetail : '$addressDetail, $area';

      final estimatedPrice = _plateStylePrices[_selectedStyle] ?? 0.0;
      final plateSpecSummary =
          '${_selectedStyle.toUpperCase()} | Reg: $_selectedRegion | Make: $_selectedMake';

      await FirebaseFirestore.instance.collection('order_requests').add({
        'userId': user.uid,
        'customerName': _fullNameCtrl.text.trim(),
        'contactNumber': _phoneCtrl.text.trim(),
        'deliveryAddress': deliveryAddress,
        'deliveryArea': area,
        'plateNumber': _plateNumberCtrl.text.trim().toUpperCase(),
        'plateStyle': _selectedStyle,
        'region': _selectedRegion,
        'brandMake': _selectedMake,
        'plateSpecs': plateSpecSummary,
        // Fixed, published estimate for the chosen plate style. Kept as both
        // `price` (read by OrderRequestModel and analytics) and
        // `estimatedPrice` (explicit: this is not a final invoice).
        'price': estimatedPrice,
        'estimatedPrice': estimatedPrice,
        'specialNotes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'status': 'PENDING', // UPDATED: Matches 'My Orders' screen exactly
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Plate order request submitted! Awaiting staff review.'),
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
              Text(
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
    final isHexagon = _selectedStyle == _styleStandard;
    const plateWidth = double.infinity;
    final plateHeight = _selectedStyle == _styleLarge ? 200.0 : 180.0;

    Widget innerPlate = Container(
      width: plateWidth,
      height: plateHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        // The plate mockup mimics a real white LTO plate in both themes.
        color: Colors.white,
        borderRadius: isHexagon ? null : BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyPrimary, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.scrimLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              Text(
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
              style: TextStyle(
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
              Expanded(
                child: Text(
                  _selectedRegion,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.navyPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedMake,
                style: TextStyle(
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
          Text(
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
                  Icon(Icons.pin_outlined, color: AppColors.navyPrimary),
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
              prefixIcon: Icon(Icons.style_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _plateStyles
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedStyle = val);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRegion,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Region *',
                    prefixIcon: Icon(Icons.map_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: _regions
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRegion = val);
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMake,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Motorcycle Make *',
                    prefixIcon: Icon(Icons.two_wheeler_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: _motorcycleMakes
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMake = val);
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
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
          Text(
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
              prefixIcon: Icon(Icons.person_outline,
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
            // Numeric only, capped at the 11-digit PH mobile format.
            inputFormatters: contactNumberInputFormatters,
            decoration: InputDecoration(
              labelText: 'Mobile Phone Number *',
              prefixIcon: Icon(Icons.phone_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: validateContactNumber,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedArea,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Delivery Area *',
              prefixIcon: Icon(Icons.location_on_outlined,
                  color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _deliveryAreas
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedArea = val),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Select delivery area' : null,
          ),
          const SizedBox(height: 14),
          // Areas on the list only need the street/barangay line; "Other" asks
          // for the whole address so an uncovered customer is never blocked.
          TextFormField(
            controller: _addressDetailCtrl,
            maxLines: _isOtherArea ? 2 : 1,
            textCapitalization: TextCapitalization.words,
            // Shipping addresses are capped at 35 characters.
            inputFormatters: shippingAddressInputFormatters,
            decoration: InputDecoration(
              labelText: _isOtherArea
                  ? 'Complete Shipping Address *'
                  : 'House No., Street, Barangay *',
              hintText: _isOtherArea
                  ? 'House/Unit No., Street, Barangay, City/Municipality, Province'
                  : 'e.g. 123 Rizal St., Brgy. Poblacion',
              alignLabelWithHint: _isOtherArea,
              prefixIcon:
                  Icon(Icons.home_outlined, color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter delivery address'
                : validateShippingAddress(v, required: true),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesCtrl,
            // Optional notes are capped at 30 characters.
            inputFormatters: orderNotesInputFormatters,
            decoration: InputDecoration(
              labelText: 'Special Notes / Conduction Details',
              hintText: 'e.g. Free bracket, hole spacing, or rush',
              prefixIcon:
                  Icon(Icons.notes_rounded, color: AppColors.navyPrimary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: validateOrderNotes,
          ),
        ],
      ),
    );
  }
}
