import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../screens/about_screen.dart';
import '../screens/booking_form_screen.dart';
import '../screens/booking_success_screen.dart';
import '../screens/catalog_screen.dart';
import '../screens/check_booking_screen.dart';
import '../screens/home_screen.dart';
import '../screens/property_detail_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/tentang-kami',
        pageBuilder: (_, GoRouterState state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: '/cek-booking',
        pageBuilder: (_, GoRouterState state) {
          final Map<String, String> query = state.uri.queryParameters;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: CheckBookingScreen(
              initialCode: query['code'],
              initialWhatsapp: query['wa'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/katalog',
        pageBuilder: (_, GoRouterState state) {
          final Map<String, String> query = state.uri.queryParameters;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: CatalogScreen(
              initialKeyword: query['q'] ?? '',
              initialCategoryId: int.tryParse(query['categoryId'] ?? ''),
              initialLocationId: int.tryParse(query['locationId'] ?? ''),
            ),
          );
        },
      ),
      GoRoute(
        path: '/properti/:slug',
        pageBuilder: (_, GoRouterState state) {
          final String slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: PropertyDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/properti/:slug/booking',
        pageBuilder: (_, GoRouterState state) {
          final String slug = state.pathParameters['slug'] ?? '';
          final Property? initialProperty =
              state.extra is Property ? state.extra as Property : null;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: BookingFormScreen(
              slug: slug,
              initialProperty: initialProperty,
            ),
          );
        },
      ),
      GoRoute(
        path: '/booking-berhasil',
        pageBuilder: (_, GoRouterState state) {
          final BookingSuccessArgs? args = state.extra is BookingSuccessArgs
              ? state.extra as BookingSuccessArgs
              : null;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: BookingSuccessScreen(args: args),
          );
        },
      ),
    ],
  );
});
