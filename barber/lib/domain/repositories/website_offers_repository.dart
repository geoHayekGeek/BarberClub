import '../models/website_offers_page_data.dart';

abstract class WebsiteOffersRepository {
  Future<WebsiteOffersPageData> loadOffersPage({
    required String salonId,
  });

  Future<String> subscribeToEventAlert({
    required WebsiteAlertConfig config,
    required String email,
  });
}
