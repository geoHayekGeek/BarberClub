import 'package:flutter/material.dart';

import '../constants/loyalty_ui_constants.dart';

/// Custom segmented progress bar for loyalty card.
/// Shows numbered scale (1 to totalRequiredVisits), filled segments in gold/beige.
/// Configurable via [currentVisits] and [totalRequiredVisits].
class LoyaltyProgressBar extends StatelessWidget {

  const LoyaltyProgressBar({
    super.key,
    required this.currentVisits,
    required this.totalRequiredVisits,
  })  : assert(currentVisits >= 0),
        assert(totalRequiredVisits > 0),
        assert(currentVisits <= totalRequiredVisits);
  final int currentVisits;
  final int totalRequiredVisits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalRequiredVisits.clamp(1, 20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Number scale + segments: each column = number above segment
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: LoyaltyUIConstants.segmentSpacing),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: (i + 1) <= currentVisits
                            ? theme.colorScheme.secondary
                            : Colors.white.withOpacity(0.4),
                        fontWeight: (i + 1) == currentVisits
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: LoyaltyUIConstants.textSpacing),
                    Container(
                      height: LoyaltyUIConstants.segmentHeight,
                      decoration: BoxDecoration(
                        color: (i + 1) <= currentVisits
                            ? theme.colorScheme.secondary
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
