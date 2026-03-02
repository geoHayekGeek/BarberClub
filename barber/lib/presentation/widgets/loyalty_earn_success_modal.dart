import 'package:flutter/material.dart';

import 'loyalty_success_modal.dart';

/// Earn-flow success: points added. Uses shared LoyaltySuccessModal.
class LoyaltyEarnSuccessModal extends StatelessWidget {
  const LoyaltyEarnSuccessModal({
    super.key,
    required this.pointsEarned,
    required this.newBalance,
  });

  final int pointsEarned;
  final int newBalance;

  @override
  Widget build(BuildContext context) {
    return LoyaltySuccessModal(
      title: 'Points ajoutés',
      subtitle: 'Nouveau solde : $newBalance pts',
      highlightValue: '+$pointsEarned',
    );
  }
}
