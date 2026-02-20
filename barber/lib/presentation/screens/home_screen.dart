import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';
import '../widgets/home_header.dart';
import '../widgets/home_center_content.dart';

/// Home screen (Accueil) - Hero + scrollable salons section
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewportHeight = MediaQuery.of(context).size.height;
    final salonsAsync = ref.watch(salonsListProvider);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section - full viewport height
            SizedBox(
              height: viewportHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BackgroundWithOverlay(),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: const HomeHeader(),
                  ),
                  const HomeCenterContent(),
                ],
              ),
            ),
            // Salons section
            Container(
              color: Colors.black,
              child: salonsAsync.when(
                data: (salons) {
                  if (salons.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(48),
                      child: Text(
                        'Aucun salon disponible pour le moment.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'NOS SALONS',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      for (int i = 0; i < salons.length; i++) ...[
                        _AccueilSalonSection(
                          salon: salons[i],
                          onTap: () => context.push('/salon/${salons[i].id}'),
                        ),
                        if (i < salons.length - 1)
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.3),
                          ),
                      ],
                      SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),
                error: (error, stackTrace) {
                  final message = getSalonErrorMessage(error, stackTrace);
                  return Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white70,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(salonsListProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Background image with dark overlay for hero
class _BackgroundWithOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/barber_background.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: const Color(0xFF121212));
          },
        ),
        Container(
          color: Colors.black.withOpacity(0.5),
        ),
      ],
    );
  }
}

/// Salon section for Accueil - 50% viewport height, tappable to view details
class _AccueilSalonSection extends StatelessWidget {
  final Salon salon;
  final VoidCallback onTap;

  const _AccueilSalonSection({
    required this.salon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;
    final imageUrl = AppConfig.resolveImageUrl(salon.imageUrl);

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Container(color: const Color(0xFF1A1A1A)),
              ),
              Positioned.fill(
                child: imageUrl != null && imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _placeholder();
                        },
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              Positioned(
                left: 24,
                bottom: 60,
                right: 24,
                child: Text(
                  salon.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.store, size: 64, color: Colors.white24),
      ),
    );
  }
}
