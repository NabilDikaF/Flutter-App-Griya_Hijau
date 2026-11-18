import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_repository.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/bookings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/master_data_screen.dart';
import '../screens/properties_screen.dart';
import '../screens/property_form_screen.dart';

final Provider<GoRouter> adminRouterProvider = Provider<GoRouter>((Ref ref) {
  final AdminSessionNotifier session = ref.watch(adminSessionProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: session,
    redirect: (_, GoRouterState state) {
      final bool loggedIn = session.isLoggedIn;
      final bool onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) {
        return '/login';
      }
      if (loggedIn && onLogin) {
        return '/dashboard';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/properties',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminPropertiesScreen(),
        ),
      ),
      GoRoute(
        path: '/properties/new',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminPropertyFormScreen(),
        ),
      ),
      GoRoute(
        path: '/properties/:id/edit',
        pageBuilder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: AdminPropertyFormScreen(propertyId: id),
          );
        },
      ),
      GoRoute(
        path: '/bookings',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminBookingsScreen(),
        ),
      ),
      GoRoute(
        path: '/bookings/:id',
        pageBuilder: (_, GoRouterState state) {
          final int id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: AdminBookingDetailScreen(bookingId: id),
          );
        },
      ),
      GoRoute(
        path: '/master-data',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AdminMasterDataScreen(),
        ),
      ),
    ],
  );
});
