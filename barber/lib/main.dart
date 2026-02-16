import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/loyalty_providers.dart';
import 'presentation/widgets/loyalty_reward_modal.dart';
import 'presentation/widgets/loyalty_reward_celebration_modal.dart';
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
      fcmService.setupListeners((String type) {
        ref.read(qrDialogCloserProvider)?.call();
        ref.read(qrDialogCloserProvider.notifier).state = null;

        if (type == 'LOYALTY_REWARD') {
          _showRewardCelebration();
        } else {
          _showLoyaltyPointModal();
        }

        ref.invalidate(loyaltyCardProvider);
        ref.invalidate(loyaltyCouponsProvider);
      });
    });
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
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
