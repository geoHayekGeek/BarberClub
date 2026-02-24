import '../models/offer.dart';
import '../models/global_offer.dart';

/// Throws [ApiError] on failure.
abstract class OfferRepository {
  /// Global promotions (all salons)
  Future<List<GlobalOffer>> getGlobalOffers();

  /// Prestations (pricing) for one salon
  Future<List<Offer>> getPrestations(String salonId);

  Future<Offer> getOfferById(String id);
}