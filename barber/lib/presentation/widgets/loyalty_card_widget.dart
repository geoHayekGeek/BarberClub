import 'package:flutter/material.dart';

import '../../domain/models/loyalty_card_data.dart';
import '../constants/loyalty_ui_constants.dart';
import 'loyalty_progress_bar.dart';

/// Digital loyalty card widget.
/// Displays member info, progress gauge, and reward.
/// Reads data from [data]; no logic inside.
class LoyaltyCardWidget extends StatelessWidget {
  final LoyaltyCardData data;

  const LoyaltyCardWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * LoyaltyUIConstants.cardWidthFraction;

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Container(
          padding: const EdgeInsets.all(LoyaltyUIConstants.cardPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(LoyaltyUIConstants.cardBorderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: full name + member since
              Text(
                data.fullName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LoyaltyUIConstants.textSpacing),
              Text(
                LoyaltyStrings.memberSinceDate(data.memberSince),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LoyaltyUIConstants.sectionSpacing),

              // Progress / gauge
              LoyaltyProgressBar(
                currentVisits: data.currentVisits,
                totalRequiredVisits: data.totalRequiredVisits,
              ),
              const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
              Text(
                LoyaltyStrings.visitsText(
                  data.currentVisits,
                  data.totalRequiredVisits,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: LoyaltyUIConstants.textSpacing),
              Text(
                data.rewardLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: LoyaltyUIConstants.sectionSpacing),

              // Description
              Text(
                LoyaltyStrings.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
