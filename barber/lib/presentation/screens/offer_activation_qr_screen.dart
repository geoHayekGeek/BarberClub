import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/offer_providers.dart';

/// Full-screen QR for offer activation. User presents this to the barber to scan.
/// If user exits without barber scan, the pending activation is cancelled so the offer shows "Activer" again.
class OfferActivationQrScreen extends ConsumerStatefulWidget {
  const OfferActivationQrScreen({
    super.key,
    required this.offerId,
    required this.qrPayload,
  });

  final String offerId;
  final String qrPayload;

  @override
  ConsumerState<OfferActivationQrScreen> createState() => _OfferActivationQrScreenState();
}

class _OfferActivationQrScreenState extends ConsumerState<OfferActivationQrScreen> {
  bool _isExiting = false;

  Future<void> _onExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      if (widget.offerId.isNotEmpty) {
        await ref.read(offerRepositoryProvider).cancelPendingActivation(widget.offerId);
      }
    } finally {
      ref.invalidate(activationStatesProvider);
      ref.invalidate(myOffersProvider);
      ref.invalidate(activeOffersProvider);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _isExiting ? null : () => _onExit(),
          ),
          title: const Text(
            'Activation d\'offre',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  'Présentez ce QR au barbier',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Le barbier doit scanner ce QR pour activer l\'offre.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: QrImageView(
                      data: widget.qrPayload,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
