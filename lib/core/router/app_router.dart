import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';

import '../../features/shell/presentation/main_navigation_shell.dart';
import '../../features/parcels/presentation/parcels_dashboard_screen.dart';
import '../../features/parcels/presentation/parcel_detail_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/returns/presentation/returns_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/admin/presentation/staff_approval_screen.dart';
import '../../features/qr_customers/presentation/customer_list_screen.dart';
import '../../features/qr_customers/presentation/reseller_scanner_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';

import '../../features/customer/presentation/customer_shell.dart';
import '../../features/customer/presentation/order_request_form_screen.dart';
import '../../features/customer/presentation/customer_my_orders_screen.dart';

// NEW: Module 11 Support Chat Imports
import '../../features/support_chat/presentation/chat_thread_screen.dart';
import '../../features/support_chat/presentation/admin_inbox_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(userProfileProvider, (_, __) => notifyListeners());
    ref.listen(authFlowInProgressProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);
  var signingOutBlockedAccount = false;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final currentLoc = state.uri.path;

      // Keep the login screen visible while credentials are being verified so
      // the router cannot jump to a portal before the profile is checked.
      if (ref.read(authFlowInProgressProvider)) {
        return null;
      }

      final authState = ref.read(authStateProvider);
      final userProfile = ref.read(userProfileProvider);

      final isUserLoggedIn = authState.value != null;

      final isAuthLoading = authState.isLoading;
      final isProfileLoading = isUserLoggedIn &&
          (userProfile.isLoading ||
              (!userProfile.hasValue && !userProfile.hasError));

      if (isAuthLoading || isProfileLoading) {
        return null;
      }

      if (!isUserLoggedIn) {
        if (currentLoc == '/login' || currentLoc == '/signup') {
          return null;
        }
        return '/login';
      }

      // Signed in but no Firestore profile: never treat this as a customer.
      // Sign the account out and send it back to the login screen.
      if (userProfile.value == null) {
        if (!signingOutBlockedAccount) {
          signingOutBlockedAccount = true;
          Future.microtask(() async {
            try {
              await ref.read(authRepositoryProvider).signOut();
            } finally {
              signingOutBlockedAccount = false;
            }
          });
        }
        return '/login';
      }

      // Pending or rejected staff must never reach a portal, even if they
      // still have a cached Firebase session from a previous version.
      final status = userProfile.value!.status.trim().toLowerCase();
      if (status == AppConstants.accountStatusPending ||
          status == AppConstants.accountStatusRejected) {
        if (!signingOutBlockedAccount) {
          signingOutBlockedAccount = true;
          Future.microtask(() async {
            try {
              await ref.read(authRepositoryProvider).signOut();
            } finally {
              signingOutBlockedAccount = false;
            }
          });
        }
        return '/login';
      }

      final rawRole = userProfile.value!.role.trim().toLowerCase();
      final isAdmin =
          rawRole == 'admin' || rawRole == AppConstants.roleAdmin.toLowerCase();
      final isStaff =
          rawRole == 'staff' || rawRole == AppConstants.roleStaff.toLowerCase();
      final isCustomer = !isAdmin && !isStaff;

      // Staff registration approvals are owner/admin-only.
      if (currentLoc.startsWith('/profile/staff-approvals') && !isAdmin) {
        return '/parcels';
      }

      if (isCustomer) {
        if (!currentLoc.startsWith('/customer')) {
          return '/customer';
        }
        return null;
      }

      if (isAdmin || isStaff) {
        if (currentLoc == '/splash' ||
            currentLoc == '/login' ||
            currentLoc == '/signup' ||
            currentLoc.startsWith('/customer')) {
          return '/parcels';
        }

        if (currentLoc.startsWith('/analytics') && !isAdmin) {
          return '/parcels';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers',
        builder: (context, state) => const CustomerListScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/reseller-scanner',
        builder: (context, state) => const ResellerScannerScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer',
        builder: (context, state) => const CustomerShell(),
        routes: [
          GoRoute(
            path: 'new-order',
            builder: (context, state) => const OrderRequestFormScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const CustomerMyOrdersScreen(),
          ),
          // NEW: Customer Chat Thread Route
          GoRoute(
            path: 'support/thread/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final subject = state.extra as String? ?? 'Support';
              return ChatThreadScreen(threadId: id, subject: subject);
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/parcels',
                builder: (context, state) => const ParcelsDashboardScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return ParcelDetailScreen(parcelId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dispatch',
                builder: (context, state) => const DispatchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/returns',
                builder: (context, state) => const ReturnsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'customers',
                    builder: (context, state) => const CustomerListScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'reseller-scanner',
                    builder: (context, state) => const ResellerScannerScreen(),
                  ),
                  // Admin/owner-only staff registration approvals.
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'staff-approvals',
                    builder: (context, state) => const StaffApprovalScreen(),
                  ),
                  // NEW: Admin Support Inbox Route
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'support-inbox',
                    builder: (context, state) => const AdminInboxScreen(),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: ':id',
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final subject =
                              state.extra as String? ?? 'Support Request';
                          return ChatThreadScreen(
                              threadId: id, subject: subject);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
