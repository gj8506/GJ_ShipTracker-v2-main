import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Explicit import to bridge the provider
import '../services/connectivity_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    // Only reserve the status-bar inset while the banner is actually shown.
    // When online the banner collapses to zero height so the app bar can sit
    // flush at the top of the screen.
    final topInset = MediaQuery.paddingOf(context).top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isOffline ? 32 + topInset : 0,
      width: double.infinity,
      color: AppColors.statusPending,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: AppColors.textOnPrimary, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Offline • Working from local cache',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
