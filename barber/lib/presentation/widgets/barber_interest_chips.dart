import 'package:flutter/material.dart';

import '../constants/barber_ui_constants.dart';

/// Centres d'intérêt as chips / pills. Wraps to next line.
class BarberInterestChips extends StatelessWidget {
  final List<String> interests;

  const BarberInterestChips({
    super.key,
    required this.interests,
  });

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          BarberStrings.centresInteret,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: BarberUIConstants.chipSpacing),
        Wrap(
          spacing: BarberUIConstants.chipSpacing,
          runSpacing: BarberUIConstants.chipRunSpacing,
          children: interests
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
