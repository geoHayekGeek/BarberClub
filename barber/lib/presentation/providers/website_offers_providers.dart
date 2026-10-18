import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/website_offers_repository_impl.dart';
import '../../domain/models/website_offers_page_data.dart';
import '../../domain/repositories/website_offers_repository.dart';
import 'salon_providers.dart';

final websiteOffersRepositoryProvider = Provider<WebsiteOffersRepository>((
  ref,
) {
  return WebsiteOffersRepositoryImpl();
});

/// Loads every published salon's offers page and keeps them together
/// on the app offers page. This screen is intentionally independent from the
/// reservation flow's selected salon.
final websiteOffersPagesProvider =
    FutureProvider.autoDispose<List<WebsiteOffersPageData>>((ref) async {
      final repository = ref.watch(websiteOffersRepositoryProvider);
      final salons = await ref.watch(salonsListProvider.future);
      return Future.wait(
        salons.map(
          (salon) =>
              repository.loadOffersPage(salonId: salon.reservationSalonId),
        ),
      );
    });
