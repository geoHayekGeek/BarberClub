// lib/presentation/providers/offer_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../data/repositories/offer_repository_impl.dart';
import 'auth_providers.dart';

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return OfferRepositoryImpl(dioClient: dioClient);
});

// Use .family so the UI can pass a salonId to this provider
final offersListProvider = FutureProvider.autoDispose.family<List<Offer>, String?>((ref, salonId) async {
  final repository = ref.watch(offerRepositoryProvider);
  
  // Now this will no longer throw an error because the interface is updated!
  return repository.getOffers(salonId: salonId);
});