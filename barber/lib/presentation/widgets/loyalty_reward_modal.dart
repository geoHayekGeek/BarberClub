import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_client.dart';
import '../constants/loyalty_ui_constants.dart';

/// Premium animated reward modal shown when a loyalty point is added.
class LoyaltyRewardModal extends StatefulWidget {
  const LoyaltyRewardModal({super.key});

  @override
  State<LoyaltyRewardModal> createState() => _LoyaltyRewardModalState();
}

class _LoyaltyRewardModalState extends State<LoyaltyRewardModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildCard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: LoyaltyUIConstants.cardPadding),
      padding: const EdgeInsets.all(LoyaltyUIConstants.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(LoyaltyUIConstants.cardBorderRadius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD4AF37),
            ),
            alignment: Alignment.center,
            child: Text(
              '+1',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
          Text(
            'Point ajouté',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: LoyaltyUIConstants.textSpacing),
          Text(
            'Votre carte fidélité a été mise à jour.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
          SizedBox(
            width: double.infinity,
            height: LoyaltyUIConstants.minTouchTargetSize,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  GoRouter.of(ctx).push('/carte-fidelite');
                }
              },
              child: const Text('Voir ma carte'),
            ),
          ),
        ],
      ),
    );
  }
}
