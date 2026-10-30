import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import 'auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 2-second branded splash hold
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authUser = ref.read(authStateProvider).value;
    if (authUser != null) {
      context.go('/parcels');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(
              size: 130,
              circular: true,
              borderColor: AppColors.navyPrimary,
            ),
            SizedBox(height: 24),
            Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.navyPrimary,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppConstants.appSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.logoBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
