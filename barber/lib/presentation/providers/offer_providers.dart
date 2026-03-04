import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/global_offer.dart';
import '../../domain/models/client_offer.dart';
import '../../domain/models/my_offer_item.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../data/repositories/offer_repository_impl.dart';
import 'auth_providers.dart';

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return OfferRepositoryImpl(dioClient: dioClient);
});

/// Global offers (promotions) - legacy, returns empty
final globalOffersListProvider = FutureProvider.autoDispose<List<GlobalOffer>>((ref) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getGlobalOffers();
});

/// Active client offers feed (event, flash, pack, permanent)
final activeOffersProvider = FutureProvider.autoDispose<List<ClientOffer>>((ref) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getActiveOffers();
});

/// User's activated offers (Mes offres). Requires auth. Returns [] when unauthenticated or error.
final myOffersProvider = FutureProvider.autoDispose<List<MyOfferItem>>((ref) async {
  try {
    final repository = ref.watch(offerRepositoryProvider);
    return await repository.getMyOffers();
  } catch (_) {
    return [];
  }
});

/// Set of offer IDs the current user has activated (for En cours "Activée" state)
final activatedOfferIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final myOffers = await ref.watch(myOffersProvider.future);
  return myOffers
      .where((o) => o.status == 'activated')
      .map((o) => o.offer.id)
      .toSet();
});

/// Activation status per offer (pending_scan, activated, used, etc.) for feed button states.
final activationStatesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  try {
    final repository = ref.watch(offerRepositoryProvider);
    return await repository.getActivationStates();
  } catch (_) {
    return {};
  }
});

/// Prestations (pricing) for a single salon
final prestationsListProvider = FutureProvider.autoDispose.family<List<Offer>, String>((ref, salonId) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getPrestations(salonId);
});