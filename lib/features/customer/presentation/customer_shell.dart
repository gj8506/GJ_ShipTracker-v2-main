import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
import 'customer_home_screen.dart';
import 'order_request_form_screen.dart';
import 'customer_my_orders_screen.dart';
import 'customer_support_screen.dart';
import 'customer_profile_screen.dart';
import '../../chatbot/presentation/chatbot_screen.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int _currentIndex = 0;

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final media = MediaQuery.of(context);
    final screens = [
      CustomerHomeScreen(
        onNavigateToRequest: () => _onTabChanged(1),
        onNavigateToOrders: () => _onTabChanged(2),
        onNavigateToSupport: () => _onTabChanged(3),
      ),
      OrderRequestFormScreen(
        onOrderSubmitted: () => _onTabChanged(2),
      ),
      const CustomerMyOrdersScreen(),
      const CustomerSupportScreen(),
      const CustomerProfileScreen(),
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
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.chromeBlue,
          border: Border(
            top: BorderSide(color: AppColors.borderStrong, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.chromeBlue,
          indicatorColor: AppColors.navyPrimary.withValues(alpha: 0.14),
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabChanged,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'New Plate',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'My Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent_rounded),
              label: 'Support',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
