import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/client_offer.dart';
import '../utils/offer_date_format.dart';
import 'offer_countdown_timer.dart';

String _typeLabelFr(ClientOffer o) {
  if (o.isFlash) return 'Offre flash';
  if (o.isPack) return 'Pack';
  if (o.isPermanent) return 'Offre permanente';
  if (o.isEvent) return 'Evenement';
  return o.type;
}

/// Card for [ClientOffer] in "Offres en cours" / "Offres a venir" feeds.
class OfferPublicCard extends StatefulWidget {
  const OfferPublicCard({
    super.key,
    required this.offer,
    required this.isUpcoming,
    required this.activationStatus,
    this.onRequestActivation,
    this.onLoginRequired,
    this.isAuthenticated = false,
  });

  final ClientOffer offer;
  final bool isUpcoming;
  final String activationStatus;
  final Future<void> Function()? onRequestActivation;
  final VoidCallback? onLoginRequired;
  final bool isAuthenticated;

  @override
  State<OfferPublicCard> createState() => _OfferPublicCardState();
}

class _OfferPublicCardState extends State<OfferPublicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holoController;
  late final Animation<double> _holoShift;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _holoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _holoShift = CurvedAnimation(
      parent: _holoController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _holoController.dispose();
    super.dispose();
  }

  void _handleActivate() {
    if (_isActivating || widget.onRequestActivation == null) return;
    setState(() => _isActivating = true);
    widget.onRequestActivation!().whenComplete(() {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final imageUrl = AppConfig.resolveImageUrl(offer.imageUrl);
    final hasImage = imageUrl != null && imageUrl.startsWith('http');

    final upcoming = widget.isUpcoming;
    final showActivationCta = !upcoming && offer.supportsQrActivation;
    final canActivate =
        showActivationCta &&
        widget.isAuthenticated &&
        widget.onRequestActivation != null;
    final needsLoginToActivate = showActivationCta && !widget.isAuthenticated;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF090909),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _holoShift,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _HoloSweepPainter(progress: _holoShift.value),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IgnorePointer(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  _OfferHeroImage(
                    imageUrl: imageUrl,
                    label: _typeLabelFr(offer).toUpperCase(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(label: _typeLabelFr(offer).toUpperCase()),
                          if (upcoming) const _MetaPill(label: 'A VENIR'),
                          if (!upcoming && offer.isFlash)
                            const _MetaPill(label: 'FLASH'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              offer.title,
                              style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.45,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DiscountBadge(label: offer.discountBadge),
                        ],
                      ),
                      if (offer.description != null &&
                          offer.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          offer.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.74),
                            height: 1.45,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (upcoming) ...[
                        const SizedBox(height: 12),
                        _InfoLine(
                          icon: Icons.event_available_rounded,
                          text:
                              'Disponible a partir du ${formatOfferDateTimeFr(offer.startsAt)}',
                          strong: true,
                        ),
                        if (offer.endsAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _InfoLine(
                              icon: Icons.schedule_rounded,
                              text:
                                  'Jusqu\'au ${formatOfferDateTimeFr(offer.endsAt!)}',
                            ),
                          ),
                      ],
                      if (!upcoming &&
                          offer.isFlash &&
                          offer.maxSpots != null) ...[
                        const SizedBox(height: 12),
                        _SpotsProgress(offer: offer),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: upcoming
                                ? const SizedBox.shrink()
                                : (offer.endsAt != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.04,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.08,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.timer_outlined,
                                                size: 15,
                                                color: Colors.white.withOpacity(
                                                  0.6,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OfferCountdownTimer(
                                                  endsAt: offer.endsAt,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white
                                                        .withOpacity(0.75),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Text(
                                          'Sans date de fin',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(
                                              0.56,
                                            ),
                                          ),
                                        )),
                          ),
                          const SizedBox(width: 10),
                          if (upcoming)
                            const _ActionPill(
                              label: 'Bientot disponible',
                              enabled: false,
                            )
                          else if (canActivate)
                            _ActivationButton(
                              activationStatus: widget.activationStatus,
                              isActivating: _isActivating,
                              onActivate: _handleActivate,
                            )
                          else if (needsLoginToActivate)
                            _ActionPill(
                              label: 'Se connecter',
                              enabled: true,
                              onTap: widget.onLoginRequired,
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferHeroImage extends StatelessWidget {
  const _OfferHeroImage({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.75,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF121212)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.12),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.86),
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _MetaPill(label: label, compact: true),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong
        ? Colors.white.withOpacity(0.88)
        : Colors.white.withOpacity(0.62);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotsProgress extends StatelessWidget {
  const _SpotsProgress({required this.offer});

  final ClientOffer offer;

  @override
  Widget build(BuildContext context) {
    final max = offer.maxSpots ?? 0;
    final taken = offer.spotsTaken;
    final remaining = (max - taken).clamp(0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Places restantes : $remaining',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: max > 0 ? (taken / max).clamp(0.0, 1.0) : 0,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.78),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ActivationButton extends StatelessWidget {
  const _ActivationButton({
    required this.activationStatus,
    required this.isActivating,
    required this.onActivate,
  });

  final String activationStatus;
  final bool isActivating;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final isUsed = activationStatus == 'used';
    final isActivated = activationStatus == 'activated';
    final isPendingScan = activationStatus == 'pending_scan';
    final disabled = isUsed || isActivated || isPendingScan || isActivating;

    late final String label;
    if (isUsed) {
      label = 'Utilisee';
    } else if (isActivated) {
      label = 'Offre activee';
    } else if (isPendingScan || isActivating) {
      label = 'En attente';
    } else {
      label = 'Activer';
    }

    return _ActionPill(
      label: label,
      enabled: !disabled,
      emphasized: isActivated,
      showArrow: !disabled && !isActivated,
      showCheck: isActivated,
      onTap: disabled ? null : onActivate,
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    this.enabled = true,
    this.emphasized = false,
    this.showArrow = false,
    this.showCheck = false,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final bool emphasized;
  final bool showArrow;
  final bool showCheck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = emphasized
        ? Colors.white
        : (enabled
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.035));
    final border = emphasized
        ? Colors.white
        : (enabled
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.1));
    final textColor = emphasized
        ? Colors.black
        : (enabled ? Colors.white : Colors.white.withOpacity(0.42));

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                fontFamily: 'Orbitron',
              ),
            ),
            if (showCheck) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, color: textColor, size: 14),
            ] else if (showArrow) ...[
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: textColor, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(compact ? 8 : 9),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.78),
          fontSize: compact ? 9.6 : 10,
          fontWeight: FontWeight.w600,
          letterSpacing: compact ? 0.9 : 1.0,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
          color: Colors.white,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }
}

class _HoloSweepPainter extends CustomPainter {
  const _HoloSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cardRect = Offset.zero & size;
    final xOffset = -2.0 * size.width * progress;
    final shaderRect = Rect.fromLTWH(
      xOffset,
      -size.height,
      size.width * 3.0,
      size.height * 3.0,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x26FFFFFF),
          Color(0x00FFFFFF),
          Color(0x14FFFFFF),
          Color(0x00FFFFFF),
          Color(0x1AFFFFFF),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(shaderRect);
    canvas.drawRect(cardRect, paint);
  }

  @override
  bool shouldRepaint(covariant _HoloSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
