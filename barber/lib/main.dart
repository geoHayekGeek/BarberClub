import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/providers/auth_providers.dart';
import 'core/deep_links/deep_link_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.1, // Start small but visible
      end: 1.5,   // End bigger than full size for effect
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut, // Bouncy effect
    ));

    // Start animation immediately
    _animationController.forward().then((_) {
      print('Animation completed!');
    });

    // Set system UI to black
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
    ));

    // Navigate to main app after animation with a slight delay
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ProviderScope(
                  child: MainApp(),
                ),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload image after widget is built
    precacheImage(
      const AssetImage('assets/images/barber_club_logo.png'),
      context,
    ).catchError((error) {
      print('Error preloading image: $error');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset(
                  'assets/images/barber_club_logo.png',
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return const Text('Logo not found', style: TextStyle(color: Colors.white));
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI to black immediately
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    systemNavigationBarColor: Colors.black,
  ));

  runApp(
    const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
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
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
