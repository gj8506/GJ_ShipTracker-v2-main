import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_validators.dart';
import 'auth_providers.dart';
import 'auth_error_text.dart';
import 'signup_prefill.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.prefill});

  /// Set when the user arrived here after a Google sign-in that had no app
  /// account yet. The screen then finishes that registration instead of
  /// asking for a password.
  final SignupPrefill? prefill;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  /// Google accounts sign in through Google, so an app password is optional
  /// there. Turning this on reveals the password fields below.
  bool _addPassword = false;

  /// Captured in [initState] because `ref` cannot be used from `dispose`.
  late final StateController<bool> _authFlow;

  String _selectedRole = AppConstants.roleCustomer; // 'customer' or 'staff'

  /// True when finishing the registration of a Google account that is already
  /// signed in to Firebase.
  bool get _isGoogleSetup => widget.prefill?.fromGoogleLogin == true;

  @override
  void initState() {
    super.initState();
    _authFlow = ref.read(authFlowInProgressProvider.notifier);

    final prefill = widget.prefill;
    if (prefill == null) return;

    _emailCtrl.text = prefill.email;
    if (prefill.fullName.isNotEmpty) {
      _nameCtrl.text = prefill.fullName;
    }
    if (prefill.role.trim().toLowerCase() == AppConstants.roleStaff) {
      _selectedRole = AppConstants.roleStaff;
    }
  }

  @override
  void dispose() {
    // Never leave the router paused if the user backs out mid-request.
    // The provider scope may already be gone during app shutdown or in tests,
    // so this must not throw.
    try {
      _authFlow.state = false;
    } catch (_) {
      // Ignored on purpose.
    }
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _showTermsAndPrivacyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _TermsAndPrivacySheet(),
    ).then((agreed) {
      if (agreed == true) {
        setState(() => _agreedToTerms = true);
      }
    });
  }

  Future<void> _handleSignUp() async {
    if (!_agreedToTerms) {
      _showTermsAndPrivacyModal();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    _authFlow.state = true;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signUpWithEmailPassword(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
            role: _selectedRole,
            phoneNumber: _phoneCtrl.text.trim(),
          );

      if (_selectedRole == AppConstants.roleStaff) {
        await _finishStaffRegistration();
      }
      // Customer accounts are redirected by the router after auth succeeds.
    } catch (e) {
      if (mounted) {
        _showAuthError(describeAuthError(e).message);
      }
    } finally {
      _authFlow.state = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (!_agreedToTerms) {
      _showTermsAndPrivacyModal();
      return;
    }

    _authFlow.state = true;
    setState(() => _isLoading = true);

    try {
      final name = _nameCtrl.text.trim();
      await ref.read(authRepositoryProvider).signUpWithGoogle(
            role: _selectedRole,
            fullName: name.isEmpty ? null : name,
            phoneNumber: _phoneCtrl.text.trim(),
          );

      if (_selectedRole == AppConstants.roleStaff) {
        await _finishStaffRegistration();
      }
      // Customer accounts are redirected by the router after auth succeeds.
    } catch (e) {
      if (mounted) {
        _showAuthError(describeAuthError(e, isGoogle: true).message);
      }
    } finally {
      _authFlow.state = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Finishes the registration of the Google account that is already signed in.
  ///
  /// The login screen keeps the Firebase session alive when it finds no app
  /// account, so this only creates the Firestore profile with the details
  /// collected here.
  Future<void> _handleFinishGoogleSetup() async {
    if (!_agreedToTerms) {
      _showTermsAndPrivacyModal();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    _authFlow.state = true;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).completeGoogleSignUp(
            role: _selectedRole,
            fullName: _nameCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            password: _addPassword ? _passwordCtrl.text : null,
          );

      if (_selectedRole == AppConstants.roleStaff) {
        await _finishStaffRegistration();
      }
      // Customer accounts are redirected by the router after the profile is
      // created, because userProfileProvider emits the new document.
    } catch (e) {
      if (mounted) {
        _showAuthError(describeAuthError(e, isGoogle: true).message);
      }
    } finally {
      _authFlow.state = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Staff accounts are created in a pending state. Sign them out immediately
  /// so they cannot reach the Staff Portal until an admin approves them, then
  /// show the review notice and return to the login screen.
  Future<void> _finishStaffRegistration() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // The router also blocks pending accounts, so a sign-out failure must
      // not hide the approval notice from the new staff member.
    }

    if (!mounted) return;
    await _showStaffPendingApprovalDialog();

    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _showStaffPendingApprovalDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.warningSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 36,
              color: AppColors.warningStrong,
            ),
          ),
          title: const Text(
            'Registration Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            AppConstants.staffApprovalPendingMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK, I understand',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.navyPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isGoogleSetup ? 'Finish Your Account' : 'Create Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isGoogleSetup
                      ? 'Your Google account is connected.\nAdd the details below to activate it.'
                      : 'Sign up to access tracking, orders, and\ndispatch',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
                if (_isGoogleSetup) ...[
                  const SizedBox(height: 18),
                  _GoogleAccountBanner(email: widget.prefill!.email),
                ],
                const SizedBox(height: 24),

                // Role Segmented Control
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _selectedRole = AppConstants.roleCustomer),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == AppConstants.roleCustomer
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow:
                                  _selectedRole == AppConstants.roleCustomer
                                      ? [
                                          const BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, 2))
                                        ]
                                      : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 18,
                                    color: _selectedRole ==
                                            AppConstants.roleCustomer
                                        ? AppColors.navyPrimary
                                        : AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedRole ==
                                            AppConstants.roleCustomer
                                        ? AppColors.navyPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _selectedRole = AppConstants.roleStaff),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == AppConstants.roleStaff
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedRole == AppConstants.roleStaff
                                  ? [
                                      const BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2))
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.badge_outlined,
                                    size: 18,
                                    color:
                                        _selectedRole == AppConstants.roleStaff
                                            ? AppColors.navyPrimary
                                            : AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Staff / Internal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _selectedRole == AppConstants.roleStaff
                                            ? AppColors.navyPrimary
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                _buildTextField(
                  controller: _nameCtrl,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailCtrl,
                  hint: 'Email Address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isGoogleSetup,
                  validator: (v) =>
                      !v!.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneCtrl,
                  hint: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: contactNumberInputFormatters,
                  validator: (v) =>
                      validateContactNumber(v, required: false),
                ),
                // Google accounts authenticate through Google, so a password is
                // optional there. The toggle lets the user add one anyway, so
                // they can also sign in with their email and password.
                if (_isGoogleSetup) ...[
                  const SizedBox(height: 16),
                  _buildAddPasswordToggle(),
                  if (_addPassword) ...[
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 16),
                    _buildConfirmPasswordField(),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildConfirmPasswordField(),
                ],
                const SizedBox(height: 16),

                // Terms & Privacy Checkbox
                InkWell(
                  onTap: () {
                    if (!_agreedToTerms) {
                      _showTermsAndPrivacyModal();
                    } else {
                      setState(() => _agreedToTerms = false);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: AppColors.navyPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            if (val == true) {
                              _showTermsAndPrivacyModal();
                            } else {
                              setState(() => _agreedToTerms = false);
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I agree to the Terms of Service &\nPrivacy Policy',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Sign Up Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading
                        ? null
                        : (_isGoogleSetup
                            ? _handleFinishGoogleSetup
                            : _handleSignUp),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isGoogleSetup
                                ? 'Finish Account Setup'
                                : 'Sign Up as ${_selectedRole == AppConstants.roleCustomer ? 'Customer' : 'Staff'}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // The Google account is already signed in when finishing a
                // Google registration, so only offer the button otherwise.
                if (!_isGoogleSetup) ...[
                  const _OrDivider(),
                  const SizedBox(height: 24),
                  _buildGoogleButton(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignUp,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navyPrimary,
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleGlyph(),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Optional password section for Google accounts.
  Widget _buildAddPasswordToggle() {
    return InkWell(
      onTap: () => setState(() => _addPassword = !_addPassword),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: _addPassword ? AppColors.surfaceMuted : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _addPassword ? AppColors.tealAccent : AppColors.borderLight,
            width: _addPassword ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.textTertiary),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a password (optional)',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Also lets you sign in with your email and password.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _addPassword,
              activeThumbColor: AppColors.tealAccent,
              onChanged: (val) => setState(() => _addPassword = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordCtrl,
      hint: 'Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textSecondary),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: _validatePassword,
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildTextField(
      controller: _confirmPasswordCtrl,
      hint: 'Confirm Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscureConfirm,
      suffixIcon: IconButton(
        icon: Icon(
            _obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textSecondary),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: _validateConfirmPassword,
    );
  }

  String? _validatePassword(String? value) {
    // The fields are hidden while finishing a Google account unless the user
    // asked for a password.
    if (_isGoogleSetup && !_addPassword) return null;
    return (value ?? '').length < 6
        ? 'Password must be at least 6 characters'
        : null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isGoogleSetup && !_addPassword) return null;
    return value != _passwordCtrl.text ? 'Passwords do not match' : null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        prefixIcon: Icon(icon, color: AppColors.textTertiary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? AppColors.surfaceMuted : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tealAccent, width: 1.6),
        ),
      ),
    );
  }
}

/// The "OR" rule between the password form and the Google button.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.borderLight)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: AppColors.borderLight)),
      ],
    );
  }
}

/// Offline, stylised Google "G" used by the Google buttons.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderCool, width: 1.5),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.statusInTransit,
        ),
      ),
    );
  }
}

/// Confirms which Google account is already signed in while the user finishes
/// creating their app account.
class _GoogleAccountBanner extends StatelessWidget {
  const _GoogleAccountBanner({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const _GoogleGlyph(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signed in with Google',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// DPA & Terms Bottom Sheet with Scroll-to-Bottom Enforcement
class _TermsAndPrivacySheet extends StatefulWidget {
  const _TermsAndPrivacySheet();

  @override
  State<_TermsAndPrivacySheet> createState() => _TermsAndPrivacySheetState();
}

class _TermsAndPrivacySheetState extends State<_TermsAndPrivacySheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isBottomReached = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        setState(() => _isBottomReached = true);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 20 &&
        !_scrollController.position.outOfRange) {
      if (!_isBottomReached) {
        setState(() => _isBottomReached = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
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
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: const Text(
                  '''DATA PRIVACY CONSENT FORM
Pursuant to the Data Privacy Act of 2012 (Republic Act No. 10173), we are committed to protecting your personal information. By checking the "I Agree" checkbox, you explicitly consent to the collection, processing, and storage of your personal data by GJandAsher ShipTracker.

1. DATA COLLECTION
We collect your full name, email address, contact number, and delivery address. We do not collect highly sensitive personal information or financial data within this application.

2. PURPOSE OF PROCESSING
Your personal data will be used exclusively for:
• Fulfilling and delivering your customized motorcycle plate orders.
• Communicating order updates, dispatch tracking numbers, and customer support.
• Generating customer QR codes to expedite future walk-in orders.
• Maintaining a secure and verified internal registry for order analytics and forecasting.

3. DATA PROTECTION & SHARING
We implement secure technical and organizational measures to safeguard your data. Your data is restricted to authorized staff and the administrative owner. We do not sell, rent, or trade your data. Data is only shared with standard courier services strictly for the purpose of package delivery.

4. YOUR RIGHTS
Under RA 10173, you possess the right to be informed, to access, to object, to erasure or blocking, to correct your personal data, and to file a complaint. You may request account deletion at any time by contacting our support channel.

TERMS OF SERVICE
1. Custom plates are novelty/temporary replacements. You hold GJandAsher harmless from legal liabilities arising from improper use on public roads.
2. Estimated prices may adjust based on final courier fees.
3. Order cancellations must be made before the production stage begins.

Scroll to the bottom to agree.''',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textPrimary, height: 1.6),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBottomReached
                      ? AppColors.navyPrimary
                      : AppColors.surfaceVariant,
                  foregroundColor: _isBottomReached
                      ? AppColors.textOnPrimary
                      : AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isBottomReached
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(
                  _isBottomReached
                      ? 'I Agree to the Terms & Privacy Policy'
                      : 'Scroll to the bottom to agree',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
