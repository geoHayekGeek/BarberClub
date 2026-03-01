import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';
import 'domain/models/user.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/loyalty_providers.dart';
import 'presentation/widgets/loyalty_reward_modal.dart';
import 'presentation/widgets/loyalty_reward_celebration_modal.dart';
import 'presentation/widgets/loyalty_earn_success_modal.dart';
import 'core/deep_links/deep_link_service.dart';
import 'core/services/fcm_service.dart';
import 'core/network/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FcmService.initialize();
  } catch (_) {
    // Firebase init failed
  }
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).bootstrapSession();
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.setupListeners((String type, [Map<String, String>? data]) {
        final user = ref.read(authStateProvider).user;
        if (user?.isAdmin == true) return;

        if (type == 'LOYALTY_EARN' && data != null) {
          ref.read(qrDialogCloserProvider)?.call();
          ref.read(qrDialogCloserProvider.notifier).state = null;
          ref.invalidate(loyaltyV2StateProvider);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLoyaltyEarnSuccess(data);
          });
          return;
        }

        ref.read(qrDialogCloserProvider)?.call();
        ref.read(qrDialogCloserProvider.notifier).state = null;

        if (type == 'LOYALTY_REWARD') {
          _showRewardCelebration();
        } else if (type == 'LOYALTY_POINT') {
          _showLoyaltyPointModal();
        } else if (type == 'COUPON_REDEEMED') {
          _showCouponRedeemedMessage();
        }

        ref.invalidate(loyaltyCardProvider);
        ref.invalidate(loyaltyCouponsProvider);
      });
    });
  }

  void _showLoyaltyEarnSuccess(Map<String, String> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final pointsEarned = int.tryParse(data['pointsEarned'] ?? '') ?? 0;
    final newBalance = int.tryParse(data['newBalance'] ?? '') ?? 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LoyaltyEarnSuccessModal(
        pointsEarned: pointsEarned,
        newBalance: newBalance,
      ),
    );
  }

  void _showRewardCelebration() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LoyaltyRewardCelebrationModal(),
    );
  }

  void _showLoyaltyPointModal() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LoyaltyRewardModal(),
    );
  }

  void _showCouponRedeemedMessage() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coupe offerte utilisée. Merci, à bientôt.'),
        backgroundColor: Color(0xFFD4AF37),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    
    // Initialize deep link service when router is available
    // Use post-frame callback to ensure router is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.initialize(router);
    });

    return MaterialApp.router(
      title: 'Barber Club',
      theme: AppTheme.darkTheme,
      scrollBehavior: AppScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
