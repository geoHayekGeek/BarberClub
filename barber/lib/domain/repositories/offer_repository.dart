import '../models/offer.dart';

/// Throws [ApiError] on failure.

abstract class OfferRepository {
  // Add {String? salonId} here to match your Implementation
  Future<List<Offer>> getOffers({String? salonId}); 
  
  Future<Offer> getOfferById(String id);
}