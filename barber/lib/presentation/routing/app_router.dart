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
import '../screens/placeholder_screen.dart';
import '../screens/salons_list_screen.dart';
import '../screens/salon_detail_screen.dart';
import '../screens/barbers_list_screen.dart';
import '../screens/barber_detail_screen.dart';
import '../../core/network/dio_client.dart';

/// App router configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
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
          // Email passed via extra when navigating from ForgotPasswordScreen
          final email = state.extra is String ? state.extra as String : '';
          if (email.isEmpty) {
            return const LoginScreen();
          }
          return ResetPasswordScreen(email: email);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/rdv',
        name: 'rdv',
        builder: (context, state) => const RdvScreen(),
      ),
      GoRoute(
        path: '/compte',
        name: 'compte',
        builder: (context, state) => const CompteScreen(),
      ),
      GoRoute(
        path: '/coiffeurs',
        name: 'coiffeurs',
        builder: (context, state) => const BarbersListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'barber-detail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return BarberDetailScreen(barberId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/salons',
        name: 'salons',
        builder: (context, state) => const SalonsListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'salon-detail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return SalonDetailScreen(salonId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/carte-fidelite',
        name: 'carte-fidelite',
        builder: (context, state) => const LoyaltyCardScreen(),
      ),
      GoRoute(
        path: '/offres',
        name: 'offres',
        builder: (context, state) => const PlaceholderScreen(title: 'Offres'),
      ),
    ],
  );
});
