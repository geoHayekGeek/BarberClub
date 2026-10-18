import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/website_catalog_repository.dart';

final websiteCatalogProvider = Provider<WebsiteCatalogRepository>((ref) {
  return WebsiteCatalogRepository();
});
