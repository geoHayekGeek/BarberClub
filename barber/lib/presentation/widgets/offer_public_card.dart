import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/client_offer.dart';
import '../utils/offer_date_format.dart';
import 'offer_countdown_timer.dart';

String _typeLabelFr(ClientOffer o) {
  if (o.isFlash) return 'Offre flash';
  if (o.isPack) return 'Pack';
  if (o.isPermanent) return 'Offre permanente';
  if (o.isEvent) return 'Événement';
  return o.type;
}

/// Card for [ClientOffer] in Offres en cours / Offres à venir feeds.
class OfferPublicCard extends StatefulWidget {
  const OfferPublicCard({
    super.key,
    required this.offer,
    required this.isUpcoming,
    required this.activationStatus,
    this.onRequestActivation,
  });

  final ClientOffer offer;
  final bool isUpcoming;
  final String activationStatus;
  final Future<void> Function()? onRequestActivation;

  @override
  State<OfferPublicCard> createState() => _OfferPublicCardState();
}

class _OfferPublicCardState extends State<OfferPublicCard> {
  bool _isActivating = false;

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
    final upcoming = widget.isUpcoming;
    final canActivate =
        !upcoming && offer.supportsQrActivation && widget.onRequestActivation != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl.startsWith('http')) const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabelFr(offer),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.75),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    offer.discountBadge,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (offer.description != null && offer.description!.trim().isNotEmpty)
              Text(
                offer.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (upcoming) ...[
              const SizedBox(height: 10),
              Text(
                'Disponible à partir du ${formatOfferDateTimeFr(offer.startsAt)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD4AF37).withOpacity(0.95),
                ),
              ),
              if (offer.endsAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Jusqu\'au ${formatOfferDateTimeFr(offer.endsAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ],
            ],
            if (!upcoming && offer.isFlash && offer.maxSpots != null) ...[
              const SizedBox(height: 8),
              Text(
                'Places restantes : ${(offer.maxSpots! - offer.spotsTaken).clamp(0, offer.maxSpots!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: offer.maxSpots! > 0
                      ? (offer.spotsTaken / offer.maxSpots!).clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: upcoming
                      ? const SizedBox.shrink()
                      : (offer.endsAt != null
                          ? OfferCountdownTimer(
                              endsAt: offer.endsAt,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Text(
                              'Sans date de fin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.55),
                              ),
                            )),
                ),
                if (upcoming)
                  _GlassShell(
                    label: 'Bientôt disponible',
                    onTap: null,
                    isActivated: false,
                    showCheck: false,
                  )
                else if (canActivate)
                  _ActivationButton(
                    activationStatus: widget.activationStatus,
                    isActivating: _isActivating,
                    onActivate: _handleActivate,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
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
    String labelBtn;
    if (isUsed) {
      labelBtn = 'Utilisée';
    } else if (isActivated) {
      labelBtn = 'Offre activée';
    } else if (isPendingScan || isActivating) {
      labelBtn = 'En attente de validation';
    } else {
      labelBtn = 'Activer l\'offre';
    }
    return _GlassShell(
      label: labelBtn,
      onTap: disabled ? null : onActivate,
      isActivated: isActivated,
      showCheck: isActivated,
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.label,
    this.onTap,
    this.isActivated = false,
    this.showCheck = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isActivated;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onTap == null
                ? Colors.grey.withOpacity(0.35)
                : (isActivated ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.grey.withOpacity(0.45)),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActivated
                ? [
                    const Color(0xFFD4AF37).withOpacity(0.15),
                    const Color(0xFFD4AF37).withOpacity(0.05),
                  ]
                : [
                    const Color(0xFF2A2A2A),
                    const Color(0xFF1F1F1F),
                  ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : (isActivated ? const Color(0xFFD4AF37) : Colors.white),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontSize: 13,
              ),
            ),
            if (showCheck) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, color: Color(0xFFD4AF37), size: 16),
            ] else if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
