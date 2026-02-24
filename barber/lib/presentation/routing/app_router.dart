import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/rdv_screen.dart';
import '../screens/compte_screen.dart';
import '../screens/loyalty_card_screen.dart';
import '../screens/salon_detail_screen.dart';
import '../screens/salon_barber_selection_screen.dart';
import '../screens/barbers_by_salon_screen.dart';
import '../screens/barber_detail_screen.dart';
import '../screens/admin_scanner_screen.dart';
import '../screens/admin_compte_screen.dart';
import '../widgets/admin_app_shell.dart';
import '../providers/auth_providers.dart';
import '../../domain/models/user.dart';
import '../../core/network/dio_client.dart';
import '../screens/offers_list_screen.dart';
import '../screens/salon_offers_detail_screen.dart';
import '../widgets/bottom_nav_bar.dart';

/// Notifier used to refresh router redirect logic when auth changes.
/// Using refreshListenable avoids recreating the entire GoRouter (which would
/// reset navigation to initialLocation) when auth state changes during
/// forgot-password, login, etc.
class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _authRefreshNotifierProvider = Provider<_AuthRefreshNotifier>((ref) {
  return _AuthRefreshNotifier();
});

/// App router configuration.
/// Role-based: ADMIN -> /admin (QR scanner only). USER -> bottom nav shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_authRefreshNotifierProvider);
  ref.listen<AuthState>(authStateProvider, (_, __) {
    refreshNotifier.refresh();
  });
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      final isAuth = auth.status == AuthStatus.authenticated;
      final isAdmin = auth.user?.isAdmin == true;

      if (isAuth && isAdmin) {
        if (!loc.startsWith('/admin')) return '/admin/scanner';
        if (loc == '/admin') return '/admin/scanner';
      } else if (isAuth && !isAdmin) {
        if (loc == '/login' || loc == '/signup') return '/home';
        if (loc.startsWith('/admin')) return '/home';
      } else {
        if (loc.startsWith('/admin') || loc.startsWith('/home') || loc.startsWith('/carte-fidelite') ||
            loc.startsWith('/rdv') || loc.startsWith('/coiffeurs') || loc.startsWith('/offres') ||
            loc == '/compte') return '/login';
      }
      if (isAuth && !isAdmin && loc.startsWith('/salons')) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final email = state.extra is String ? state.extra as String : '';
          if (email.isEmpty) {
            return const LoginScreen();
          }
          return ResetPasswordScreen(email: email);
        },
      ),
      GoRoute(
        path: '/salon/:id',
        name: 'salon-detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SalonDetailScreen(salonId: id);
        },
      ),
      GoRoute(
        path: '/compte',
        name: 'compte',
        builder: (context, state) => const CompteScreen(),
      ),
      // Admin app: shell (scanner + compte), no bottom nav
      ShellRoute(
        builder: (context, state, child) => AdminAppShell(
          matchedLocation: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/admin',
            redirect: (context, state) {
              final path = state.uri.path;
              if (path == '/admin' || path == '/admin/') return '/admin/scanner';
              return null;
            },
            routes: [
              GoRoute(
                path: 'scanner',
                name: 'admin-scanner',
                builder: (context, state) => const AdminScannerScreen(),
              ),
              GoRoute(
                path: 'compte',
                name: 'admin-compte',
                builder: (context, state) => const AdminCompteScreen(),
              ),
            ],
          ),
        ],
      ),
      // Main app: 5 tabs with floating dock navigation
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavBar(navigationShell: navigationShell),
          );
        },
        branches: [
          // index 0: Accueil (Home + Prestations as part of home flow)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'prestations/:salonId',
                    name: 'salon-prestations',
                    builder: (context, state) {
                      final salonId = state.pathParameters['salonId'] ?? '';
                      final salonName = state.uri.queryParameters['name'] != null
                          ? Uri.decodeComponent(state.uri.queryParameters['name']!)
                          : 'Salon';
                      return SalonOffersDetailScreen(
                        salonId: salonId,
                        salonName: salonName,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // index 1: Nos coiffeurs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coiffeurs',
                name: 'coiffeurs',
                builder: (context, state) => const SalonBarberSelectionScreen(),
                routes: [
                  GoRoute(
                    path: 'salon/:salonId',
                    name: 'barbers-by-salon',
                    builder: (context, state) {
                      final salonId = state.pathParameters['salonId'] ?? '';
                      final salonName = state.uri.queryParameters['name'] != null
                          ? Uri.decodeComponent(state.uri.queryParameters['name']!)
                          : 'Salon';
                      return BarbersBySalonScreen(
                        salonId: salonId,
                        salonName: salonName,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'barber/:id',
                        name: 'barber-detail',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          final salonName = state.uri.queryParameters['name'] != null
                              ? Uri.decodeComponent(state.uri.queryParameters['name']!)
                              : null;
                          return BarberDetailScreen(barberId: id, salonName: salonName);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // index 2: RDV — center elevated button
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rdv',
                name: 'rdv',
                builder: (context, state) => const RdvScreen(),
              ),
            ],
          ),
          // index 3: Carte fidélité
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/carte-fidelite',
                name: 'carte-fidelite',
                builder: (context, state) => const LoyaltyCardScreen(),
              ),
            ],
          ),
          // index 4: Offres (global promotions only)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/offres',
                name: 'offres-base',
                builder: (context, state) => const OffersListScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
