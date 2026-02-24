import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/global_offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../data/repositories/offer_repository_impl.dart';
import 'auth_providers.dart';

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return OfferRepositoryImpl(dioClient: dioClient);
});

/// Global offers (promotions) for Offres tab
final globalOffersListProvider = FutureProvider.autoDispose<List<GlobalOffer>>((ref) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getGlobalOffers();
});

/// Prestations (pricing) for a single salon
final prestationsListProvider = FutureProvider.autoDispose.family<List<Offer>, String>((ref, salonId) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getPrestations(salonId);
});