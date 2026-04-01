import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/api_error.dart';
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

/// Raw public feed from GET /api/v1/offers: non-expired offers (current window + upcoming).
final publicOffersFeedProvider = FutureProvider.autoDispose<List<ClientOffer>>((ref) async {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getActiveOffers();
});

/// Offres en cours: started, not expired.
final currentOffersProvider = FutureProvider.autoDispose<List<ClientOffer>>((ref) async {
  final list = await ref.watch(publicOffersFeedProvider.future);
  final now = DateTime.now();
  final filtered = list.where((o) => o.isCurrentlyAvailable(now)).toList();
  filtered.sort(_compareCurrentOffers);
  return filtered;
});

/// Offres à venir: future start, not expired.
final upcomingOffersProvider = FutureProvider.autoDispose<List<ClientOffer>>((ref) async {
  final list = await ref.watch(publicOffersFeedProvider.future);
  final now = DateTime.now();
  final filtered = list.where((o) => o.isUpcoming(now)).toList();
  filtered.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return filtered;
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

/// Set of offer IDs the current user has activated (for feed "Offre activée" state)
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

int _compareCurrentOffers(ClientOffer a, ClientOffer b) {
  final aEnd = a.endsAt;
  final bEnd = b.endsAt;
  if (aEnd == null && bEnd == null) return a.title.compareTo(b.title);
  if (aEnd == null) return 1;
  if (bEnd == null) return -1;
  return aEnd.compareTo(bEnd);
}

/// Map backend/network errors to French messages for the offers feed.
String getOfferFeedErrorMessage(Object error, [StackTrace? stackTrace]) {
  if (error is ApiError) {
    switch (error.code) {
      case 'NETWORK_ERROR':
        return 'Impossible de se connecter. Vérifiez votre connexion.';
      default:
        return 'Impossible de charger les offres. Réessayez plus tard.';
    }
  }
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Impossible de se connecter. Vérifiez votre connexion.';
    }
  }
  return 'Impossible de charger les offres. Réessayez plus tard.';
}
