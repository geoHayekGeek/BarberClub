import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/website_offers_repository_impl.dart';
import '../../domain/models/website_offers_page_data.dart';
import '../../domain/repositories/website_offers_repository.dart';

final websiteOffersRepositoryProvider = Provider<WebsiteOffersRepository>((
  ref,
) {
  return WebsiteOffersRepositoryImpl();
});

/// Loads both salon offers pages from the website and keeps them together
/// on the app offers page. This screen is intentionally independent from the
/// reservation flow's selected salon.
final websiteOffersPagesProvider =
    FutureProvider.autoDispose<List<WebsiteOffersPageData>>((ref) async {
      final repository = ref.watch(websiteOffersRepositoryProvider);
      return Future.wait([
        repository.loadOffersPage(salonId: 'grenoble'),
        repository.loadOffersPage(salonId: 'meylan'),
      ]);
    });
