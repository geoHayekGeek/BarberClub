import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';

class SalonsListScreen extends ConsumerWidget {
  const SalonsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(salonsListProvider);

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: salonsAsync.when(
            data: (salons) {
              if (salons.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun salon disponible pour le moment.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < salons.length; i++) ...[
                      _SalonSectionWidget(
                        salon: salons[i],
                        onTap: () => context.push('/salons/${salons[i].id}'),
                      ),
                      if (i < salons.length - 1)
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
            error: (error, stackTrace) {
              final message = getSalonErrorMessage(error, stackTrace);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SalonSectionWidget extends StatefulWidget {
  final Salon salon;
  final VoidCallback onTap;

  const _SalonSectionWidget({
    required this.salon,
    required this.onTap,
  });

  @override
  State<_SalonSectionWidget> createState() => _SalonSectionWidgetState();
}

class _SalonSectionWidgetState extends State<_SalonSectionWidget> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;
    final imageUrl = widget.salon.imageUrl;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.salon.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
