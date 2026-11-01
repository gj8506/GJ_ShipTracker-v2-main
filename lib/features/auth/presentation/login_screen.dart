import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import 'auth_providers.dart';
import 'auth_error_text.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  // Toggle between Staff / Operations login and Customer Portal login
  bool _isCustomerPortal = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Verifies that the account has a Firestore profile and that its role
  /// matches the current login tab. Any failure signs the user out.
  Future<bool> _verifyPortalRole(User user) async {
    final authRepo = ref.read(authRepositoryProvider);
    final profile = await authRepo.getUserProfile(user.uid);

    if (profile == null) {
      // The Google/Firebase account exists, but no app account was created.
      await authRepo.signOut();
      if (mounted) {
        _showErrorSnackBar(
          'No app account was found for this sign-in. Please tap "Sign Up" '
          'and register first — you can use Continue with Google there.',
        );
      }
      return false;
    }

    // Staff registrations must be approved by the owner/admin before they can
    // access any portal. Rejected accounts are blocked permanently.
    if (profile.isPending) {
      await authRepo.signOut();
      if (mounted) {
        _showErrorSnackBar(
          'Your staff account is still awaiting admin approval. '
          'Please wait for the approval email before signing in.',
        );
      }
      return false;
    }

    if (profile.isRejected) {
      await authRepo.signOut();
      if (mounted) {
        _showErrorSnackBar(
          'Your registration was rejected. Please contact the administrator.',
        );
      }
      return false;
    }

    final rawRole = profile.role.trim().toLowerCase();
    final isStaffOrAdmin = rawRole == 'admin' ||
        rawRole == 'staff' ||
        rawRole == AppConstants.roleAdmin.toLowerCase() ||
        rawRole == AppConstants.roleStaff.toLowerCase();

    if (!_isCustomerPortal && !isStaffOrAdmin) {
      // Trying to log into Staff Portal with a Customer account
      await authRepo.signOut();
      if (mounted) {
        _showErrorSnackBar(
          'This account is registered as a Customer. Please switch to the "Customer Portal" tab to sign in.',
        );
      }
      return false;
    }

    if (_isCustomerPortal && isStaffOrAdmin) {
      // Trying to log into Customer Portal with a Staff or Admin account
      await authRepo.signOut();
      if (mounted) {
        _showErrorSnackBar(
          'Staff and Admin accounts must sign in using the "Staff Portal" tab.',
        );
      }
      return false;
    }

    return true;
  }

  // Handle standard Login (Email or Username)
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    ref.read(authFlowInProgressProvider.notifier).state = true;
    setState(() => _isLoading = true);

    final authRepo = ref.read(authRepositoryProvider);
    final rawInput = _identifierCtrl.text.trim();
    String resolvedEmail = rawInput;

    try {
      // If input is a username (no '@'), look up registered email in Firestore
      if (!rawInput.contains('@')) {
        try {
          final querySnap = await FirebaseFirestore.instance
              .collection(AppConstants.collectionUsers)
              .where('username', isEqualTo: rawInput)
              .limit(1)
              .get();

          if (querySnap.docs.isNotEmpty) {
            resolvedEmail =
                querySnap.docs.first.data()['email'] as String? ?? rawInput;
          } else {
            final altQuery = await FirebaseFirestore.instance
                .collection(AppConstants.collectionUsers)
                .where('username', isEqualTo: rawInput.toLowerCase())
                .limit(1)
                .get();

            if (altQuery.docs.isNotEmpty) {
              resolvedEmail =
                  altQuery.docs.first.data()['email'] as String? ?? rawInput;
            } else {
              throw Exception(
                  'No account found with username "$rawInput". Please sign in with your email address.');
            }
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw Exception(
              'Firestore security rules require full email to sign in. Please enter your email (e.g. name@example.com).',
            );
          }
          rethrow;
        }
      }

      // Perform authentication with Firebase Auth
      final credential = await authRepo.signInWithEmail(
        email: resolvedEmail,
        password: _passwordCtrl.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final isValidRole = await _verifyPortalRole(user);
        if (!isValidRole) {
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      var info = describeAuthError(e);

      // Email/password failed: check whether this address actually belongs to
      // a Google-only account so the message below is accurate. This is a hint
      // only — Firebase may hide the answer when email enumeration protection
      // is enabled.
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        final methods = await authRepo.signInMethodsForEmail(resolvedEmail);
        if (methods.contains('google.com') && !methods.contains('password')) {
          info = const AuthErrorInfo(
            'This account was created with Google. Tap "Continue with Google" '
            'to sign in.',
          );
        }
      }

      if (mounted) _showAuthErrorInfo(info);
    } catch (e) {
      if (mounted) _showAuthErrorInfo(describeAuthError(e));
    } finally {
      ref.read(authFlowInProgressProvider.notifier).state = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthErrorInfo(AuthErrorInfo info) {
    _showErrorSnackBar(
      info.message,
      action: info.canResetPassword
          ? SnackBarAction(
              label: 'Reset password',
              textColor: Colors.white,
              onPressed: _showForgotPasswordDialog,
            )
          : null,
    );
  }

  void _showErrorSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 6),
        action: action,
        content: Text(message),
      ),
    );
  }

  // Handle Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    ref.read(authFlowInProgressProvider.notifier).state = true;
    setState(() => _isGoogleLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final credential = await authRepo.signInWithGoogle();

      // Null means the user closed the Google account picker.
      final user = credential?.user;
      if (user != null) {
        final isValidRole = await _verifyPortalRole(user);
        if (!isValidRole) {
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(describeAuthError(e, isGoogle: true).message);
      }
    } finally {
      ref.read(authFlowInProgressProvider.notifier).state = false;
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // Forgot Password Dialog
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _identifierCtrl.text.contains('@')
            ? _identifierCtrl.text.trim()
            : '',
      ),
    );
  }

  // Direct navigation to SignupScreen
  void _navigateToSignUp() {
    context.push('/signup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogo(
                      size: 92,
                      circular: true,
                      borderColor: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      AppConstants.appSubtitle,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // Portal Mode Switcher: Staff vs Customer
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _isCustomerPortal = false),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: !_isCustomerPortal
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !_isCustomerPortal
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 16,
                                      color: !_isCustomerPortal
                                          ? AppColors.navyPrimary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Staff Portal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_isCustomerPortal
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: !_isCustomerPortal
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
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _isCustomerPortal = true),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _isCustomerPortal
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _isCustomerPortal
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_pin_outlined,
                                      size: 16,
                                      color: _isCustomerPortal
                                          ? AppColors.navyPrimary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Customer Portal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _isCustomerPortal
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: _isCustomerPortal
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
                    const SizedBox(height: 20),

                    // 1. Email or Username Input
                    TextFormField(
                      controller: _identifierCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _isCustomerPortal
                            ? 'Customer Email'
                            : 'Email or Username',
                        hintText: _isCustomerPortal
                            ? 'Enter your customer email'
                            : 'Enter your email or username',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return _isCustomerPortal
                              ? 'Please enter your email'
                              : 'Please enter your email or username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Password Input
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // 3. Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: AppColors.textOnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isCustomerPortal
                                    ? 'Sign In as Customer'
                                    : 'Sign In',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.borderSubtle)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.borderSubtle)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 6. Continue with Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed:
                            _isGoogleLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderLight),
                          foregroundColor: AppColors.navyPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGoogleLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.borderCool,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Text(
                                      'G',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.statusInTransit,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isCustomerPortal
                                        ? 'Continue with Google'
                                        : 'Continue with Google',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 7. Don't have an account? Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        InkWell(
                          onTap: _navigateToSignUp,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.0, vertical: 8.0),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.tealDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  late final TextEditingController _emailDialogCtrl;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _emailDialogCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailDialogCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailDialogCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordReset(email);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusDelivered,
            content: Text('Password reset link sent to $email'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorRed,
            content: Text('Failed to send reset link: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your registered email address and we will send you a password reset link.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailDialogCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Account Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendResetLink,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Link'),
        ),
      ],
    );
  }
}
