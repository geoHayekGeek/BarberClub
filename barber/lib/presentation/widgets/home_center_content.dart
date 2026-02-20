import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Center content widget for Home screen
/// Displays title, subtitle, and CTA button
class HomeCenterContent extends StatelessWidget {
  const HomeCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Text(
              'BARBER CLUB',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Subtitle
            Text(
              'Des coupes sur-mesure, une expérience premium.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 48),
            // CTA Button
            ElevatedButton(
              onPressed: () => context.go('/rdv'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary, // Beige/off-white
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'DÉBUTER',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
