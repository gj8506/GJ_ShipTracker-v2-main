import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../chatbot/presentation/chatbot_screen.dart';

class MainNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final role = userProfileAsync.value?.role ?? AppConstants.roleStaff;
    final isAdmin = role == AppConstants.roleAdmin;
    final isOffline = ref.watch(isOfflineProvider);
    final media = MediaQuery.of(context);

    // Define navigation destinations based on role
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: 'Parcels',
      ),
      const NavigationDestination(
        icon: Icon(Icons.local_shipping_outlined),
        selectedIcon: Icon(Icons.local_shipping_rounded),
        label: 'Dispatch',
      ),
      const NavigationDestination(
        icon: Icon(Icons.assignment_return_outlined),
        selectedIcon: Icon(Icons.assignment_return_rounded),
        label: 'Returns',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics_rounded),
          label: 'Analytics',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: MediaQuery(
              // The banner already covers the status bar while offline, so
              // drop the top inset to avoid a second empty header band.
              data: isOffline ? media.removePadding(removeTop: true) : media,
              child: navigationShell,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: AppColors.textOnPrimary,
        tooltip: 'Open support assistant',
        child: const Icon(Icons.smart_toy_rounded),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChatbotScreen()));
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.chromeBlue,
          border: Border(
            top: BorderSide(color: AppColors.borderStrong, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.chromeBlue,
          indicatorColor: AppColors.navyPrimary.withValues(alpha: 0.14),
          elevation: 0,
          selectedIndex:
              _calculateSelectedIndex(navigationShell.currentIndex, isAdmin),
          onDestinationSelected: (index) {
            _onTap(index, isAdmin);
          },
          destinations: destinations,
        ),
      ),
    );
  }

  int _calculateSelectedIndex(int routeIndex, bool isAdmin) {
    if (isAdmin) return routeIndex;
    // For staff, if routeIndex is 4 (Profile), it is the 3rd index in the bar
    if (routeIndex >= 3) {
      return (routeIndex == 4) ? 3 : 0;
    }
    return routeIndex;
  }

  void _onTap(int barIndex, bool isAdmin) {
    if (isAdmin) {
      navigationShell.goBranch(
        barIndex,
        initialLocation: barIndex == navigationShell.currentIndex,
      );
    } else {
      // Map 4-bar indexes to the real branch index
      // 0: Parcels (branch 0), 1: Dispatch (branch 1), 2: Returns (branch 2), 3: Profile (branch 4)
      final branch = barIndex == 3 ? 4 : barIndex;
      navigationShell.goBranch(
        branch,
        initialLocation: branch == navigationShell.currentIndex,
      );
    }
  }
}
