import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/rdv_screen.dart';
import '../screens/compte_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/salons_list_screen.dart';
import '../screens/salon_detail_screen.dart';
import '../screens/barbers_list_screen.dart';
import '../screens/barber_detail_screen.dart';
import '../../core/network/dio_client.dart';
import '../screens/offers_list_screen.dart';

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
          final email = state.uri.queryParameters['email'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          if (email.isEmpty || token.isEmpty) {
            return const LoginScreen();
          }
          return ResetPasswordScreen(email: email, token: token);
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
        builder: (context, state) => const PlaceholderScreen(title: 'Carte fidélité'),
      ),
      
      // --- FIXED OFFERS ROUTE ---
      // 1. Base route: Redirects to salons if no ID is provided, 
      // ensuring the user picks a salon first as requested.
      GoRoute(
        path: '/offres',
        name: 'offres-base',
        redirect: (context, state) {
          // If the user just hits '/offres', send them to pick a salon first
          return '/salons?selectFor=offers';
        },
      ),
      
      // 2. Filtered route: Displays the offers for a specific salon
      GoRoute(
        path: '/offres/:salonId',
        name: 'salon-offres',
        builder: (context, state) {
          final salonId = state.pathParameters['salonId'] ?? '';
          return OffersListScreen(salonId: salonId);
        },
      ),
    ],
  );
});