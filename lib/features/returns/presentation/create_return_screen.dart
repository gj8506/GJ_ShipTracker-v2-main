import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'returns_providers.dart';

class CreateReturnScreen extends ConsumerStatefulWidget {
  const CreateReturnScreen({super.key});

  @override
  ConsumerState<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends ConsumerState<CreateReturnScreen> {
  final _formKey = GlobalKey<FormState>();

  final _trackingController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _specsController = TextEditingController();
  final _notesController = TextEditingController();

  static const List<String> _platforms = [
    'Shopee',
    'Lazada',
    'TikTok Shop',
    'Direct / Walk-in',
  ];

  static const List<String> _resolutionTypes = [
    'Replacement',
    'Refund',
    'Repair',
    'Return to Supplier',
  ];

  static const List<String> _defectReasons = [
    'Damaged in Transit',
    'Factory Defect',
    'Wrong Item Delivered',
    'Missing Components',
    'Customer Remorse / Cancelled',
    'Other Issues',
  ];

  String _selectedPlatform = 'Shopee';
  String _selectedResolution = 'Replacement';
  String _selectedDefectReason = 'Damaged in Transit';

  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _trackingController.dispose();
    _customerNameController.dispose();
    _contactController.dispose();
    _specsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Camera and Gallery with error and permission handling
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Permission error: ${e.message ?? e.code}. Please enable Camera/Storage permissions in Settings.'),
            backgroundColor: AppColors.statusReturned,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.statusReturned,
          ),
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _submitReturnTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to log return tickets.'),
          backgroundColor: AppColors.statusReturned,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine Plate Specs and Photo details into notes
      final specs = _specsController.text.trim();
      final userNotes = _notesController.text.trim();
      final buffer = StringBuffer();

      if (specs.isNotEmpty) {
        buffer.writeln('Plate Specs: $specs');
      }
      if (userNotes.isNotEmpty) {
        buffer.writeln(userNotes);
      }
      if (_selectedImage != null) {
        buffer.writeln(
            '[Photo Attached: ${_selectedImage!.path.split('/').last}]');
      }

      final combinedNotes = buffer.toString().trim();
      final trackingNum = _trackingController.text.trim();

      // Write directly to Firestore 'returns' collection
      await FirebaseFirestore.instance.collection('returns').add({
        'trackingNumber': trackingNum,
        'defectReason': _selectedDefectReason,
        'platform': _selectedPlatform,
        'resolutionType': _selectedResolution,
        'customerName': _customerNameController.text.trim(),
        'contactNumber': _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        'notes': combinedNotes.isEmpty ? null : combinedNotes,
        'status': AppConstants.returnStatusPending,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Invalidate stream so returns log and counts update immediately
      ref.invalidate(returnsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Return ticket for "$trackingNum" logged successfully!'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save return ticket: $e'),
            backgroundColor: AppColors.statusReturned,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Log Return / Defect Ticket')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tracking Number
                TextFormField(
                  controller: _trackingController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Original Tracking Number *',
                    hintText: 'e.g. SPX123456789PH',
                    prefixIcon:
                        const Icon(Icons.qr_code, color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Original tracking number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Platform & Resolution Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPlatform,
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Platform',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _platforms.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPlatform = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedResolution,
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Resolution',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _resolutionTypes.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedResolution = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer Name
                TextFormField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Customer / Buyer Name *',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Customer name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contact Number
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contact Number (Optional)',
                    prefixIcon: const Icon(Icons.phone_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Motorcycle Plate Specifications
                TextFormField(
                  controller: _specsController,
                  decoration: InputDecoration(
                    labelText: 'Motorcycle Plate Specifications',
                    hintText: 'e.g. White plate, embossed, 4x7 with bracket',
                    prefixIcon: const Icon(Icons.two_wheeler_outlined,
                        color: AppColors.navyPrimary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Defect Reason
                DropdownButtonFormField<String>(
                  initialValue: _selectedDefectReason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Defect Category *',
                    prefixIcon: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.statusReturned),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _defectReasons.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDefectReason = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Defect Description / Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Defect Description / Notes',
                    hintText: 'Describe damage or defect details...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Clean "Photo Evidence" Card (Cloudinary text removed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.photo_library_outlined,
                              size: 20, color: AppColors.navyPrimary),
                          SizedBox(width: 8),
                          Text(
                            'Photo Evidence',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Image Preview if captured
                      if (_selectedImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.file(
                                _selectedImage!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                  onPressed: _removeSelectedImage,
                                  tooltip: 'Remove photo',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Camera and Gallery buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                side: const BorderSide(
                                    color: AppColors.textMuted),
                              ),
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined,
                                  color: AppColors.navyPrimary),
                              label: const Text(
                                'Camera',
                                style: TextStyle(
                                    color: AppColors.navyPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                side: const BorderSide(
                                    color: AppColors.textMuted),
                              ),
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_outlined,
                                  color: AppColors.navyPrimary),
                              label: const Text(
                                'Gallery',
                                style: TextStyle(
                                    color: AppColors.navyPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _submitReturnTicket,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Return Ticket',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
