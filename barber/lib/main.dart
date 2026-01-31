import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/providers/auth_providers.dart';
import 'core/deep_links/deep_link_service.dart';

void main() {
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
    // Bootstrap session on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).bootstrapSession();
    });
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
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
