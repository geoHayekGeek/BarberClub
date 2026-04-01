import '../models/offer.dart';
import '../models/global_offer.dart';
import '../models/client_offer.dart';
import '../models/my_offer_item.dart';

/// Throws [ApiError] on failure.
abstract class OfferRepository {
  /// Global promotions (all salons) - legacy
  Future<List<GlobalOffer>> getGlobalOffers();

  /// Public client offers feed: non-expired offers (current + upcoming), excludes welcome.
  /// The app splits into Offres en cours / Offres à venir.
  Future<List<ClientOffer>> getActiveOffers();

  /// Request activation: creates pending_scan and returns activationId + qrPayload for barber scan.
  Future<RequestActivationResult> requestActivation(String offerId);

  /// Cancel a pending_scan activation (e.g. when user exits QR screen without barber scan).
  Future<void> cancelActivation(String activationId);

  /// Cancel current user's pending_scan for this offer by offerId (preferred when exiting QR screen).
  Future<void> cancelPendingActivation(String offerId);

  /// User's activated offers (Mes offres). Requires auth.
  Future<List<MyOfferItem>> getMyOffers();

  /// Activation status per offer (for feed button states). Returns { offerId: status }.
  Future<Map<String, String>> getActivationStates();

  /// Prestations (pricing) for one salon
  Future<List<Offer>> getPrestations(String salonId);

  Future<Offer> getOfferById(String id);
}

class RequestActivationResult {
  final String activationId;
  final String qrPayload;

  const RequestActivationResult({
    required this.activationId,
    required this.qrPayload,
  });

  factory RequestActivationResult.fromJson(Map<String, dynamic> json) {
    return RequestActivationResult(
      activationId: json['activationId'] as String? ?? json['activation_id'] as String? ?? '',
      qrPayload: json['qrPayload'] as String? ?? json['qr_payload'] as String? ?? '',
    );
  }
}

class ActivationResult {
  final String id;
  final String offerId;
  final String status;
  final DateTime activatedAt;
  final DateTime? expiresAt;

  const ActivationResult({
    required this.id,
    required this.offerId,
    required this.status,
    required this.activatedAt,
    this.expiresAt,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    final activatedRaw = json['activatedAt'] ?? json['activated_at'];
    final expiresRaw = json['expiresAt'] ?? json['expires_at'];
    return ActivationResult(
      id: json['id'] as String? ?? '',
      offerId: json['offerId'] as String? ?? json['offer_id'] as String? ?? '',
      status: json['status'] as String? ?? 'activated',
      activatedAt: activatedRaw != null
          ? DateTime.tryParse(activatedRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw.toString()) : null,
    );
  }
}