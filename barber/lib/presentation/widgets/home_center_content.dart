import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_primary_button.dart';

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
            // --- LOGO REPLACEMENT ---
            // Replaced Text('BARBER CLUB') with Image.asset
            Image.asset(
              'assets/images/barber_club_full_logo.png', // Ensure this path matches your logo file
              width: MediaQuery.of(context).size.width * 0.8, // Sets width to 80% of screen
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 32), // Add spacing between logo and subtitle
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
            AppPrimaryButton(
              label: 'DÉBUTER',
              onTap: () => context.go('/rdv'),
            ),
          ],
        ),
      ),
    );
  }
}
