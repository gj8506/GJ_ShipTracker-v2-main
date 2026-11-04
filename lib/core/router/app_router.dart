import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../services/dpa_service.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/dpa_gate_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/signup_prefill.dart';
import '../../features/auth/presentation/splash_screen.dart';

import '../../features/shell/presentation/main_navigation_shell.dart';
import '../../features/parcels/presentation/parcels_dashboard_screen.dart';
import '../../features/parcels/presentation/parcel_detail_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/returns/presentation/returns_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/admin/presentation/staff_approval_screen.dart';
import '../../features/admin/presentation/dpa_editor_screen.dart';
import '../../features/qr_customers/presentation/customer_list_screen.dart';
import '../../features/qr_customers/presentation/reseller_scanner_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/search_summary/presentation/search_summary_screen.dart';

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
    // Re-run the redirect when the stored Data Privacy consent resolves or is
    // accepted, so the gate is shown before any portal.
    ref.listen(dpaAcceptedStatusProvider, (_, __) => notifyListeners());
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

      // Data Privacy Act consent is required before anything else, including the
      // login screen. While the stored answer is loading we stay on the splash
      // so the app never flashes a portal before the gate is checked.
      final dpaStatus = ref.read(dpaAcceptedStatusProvider);
      if (dpaStatus.isLoading) {
        return null;
      }
      final dpaAccepted = dpaStatus.value ?? false;
      if (!dpaAccepted) {
        return currentLoc == '/dpa' ? null : '/dpa';
      }

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

      // Signed in but no Firestore profile: this is a Google sign-in that has
      // not finished registration yet. The Sign Up screen completes the
      // profile for the session that is already authenticated, so let it stay.
      if (userProfile.value == null) {
        if (currentLoc == '/signup') {
          return null;
        }
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

      final role = userProfile.value!.role;
      final isAdmin = AppConstants.isAdminRole(role);
      final isStaffOrAdmin = AppConstants.isStaffOrAdminRole(role);
      final isCustomer = !isStaffOrAdmin;

      // Staff registration approvals are owner/admin-only.
      if (currentLoc.startsWith('/profile/staff-approvals') && !isAdmin) {
        return '/parcels';
      }

      // The Data Privacy Act editor is owner/admin-only.
      if (currentLoc.startsWith('/profile/dpa-editor') && !isAdmin) {
        return '/parcels';
      }

      if (isCustomer) {
        if (!currentLoc.startsWith('/customer')) {
          return AppConstants.homeRouteForRole(role);
        }
        return null;
      }

      if (isStaffOrAdmin) {
        if (currentLoc == '/splash' ||
            currentLoc == '/login' ||
            currentLoc == '/signup' ||
            currentLoc == '/dpa' ||
            currentLoc.startsWith('/customer')) {
          return AppConstants.homeRouteForRole(role);
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
        builder: (context, state) {
          final extra = state.extra;
          return SignupScreen(
            prefill: extra is SignupPrefill ? extra : null,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/dpa',
        builder: (context, state) => const DpaGateScreen(),
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
      // Admin/staff lookup for historical orders and parcels.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search-summary',
        builder: (context, state) => const SearchSummaryScreen(),
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
                  // Admin/owner-only Data Privacy Act editor.
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'dpa-editor',
                    builder: (context, state) => const DpaEditorScreen(),
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
