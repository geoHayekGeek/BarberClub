import 'dart:convert';
import 'dart:io';

import 'package:barber/core/config/app_config.dart';
import 'package:barber/data/parsers/website_offers_page_parser.dart';
import 'package:barber/data/repositories/website_catalog_repository.dart';
import 'package:dio/dio.dart';

/// Read-only integration audit of the public website and booking catalogue.
/// Run from barber/: dart run tool/audit_website.dart [--check-media]
Future<void> main(List<String> arguments) async {
  final catalogue = WebsiteCatalogRepository();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  final salons = await catalogue.getSalons();
  final result = <Map<String, dynamic>>[];
  final portraits = <String>{};
  for (final salon in salons) {
    final team = await catalogue.getBarbers(salonId: salon.id);
    final profiles = <Map<String, dynamic>>[];
    for (final barber in team) {
      final detail = await catalogue.getBarberById(barber.id);
      if (detail.image != null) portraits.add(detail.image!);
      profiles.add({
        'id': detail.id,
        'name': detail.displayName,
        'photo': detail.image,
        'bioCharacters': detail.bio.length,
        'galleryPhotos': detail.galleryImages.length,
        'galleryVideos': detail.galleryVideoUrls.length,
      });
    }
    final bookable = await dio.get<List<dynamic>>(
      '${AppConfig.reservationApiBaseUrl}/barbers',
      queryParameters: {'salon_id': salon.id},
    );
    final services = await dio.get<List<dynamic>>(
      '${AppConfig.reservationApiBaseUrl}/services',
      queryParameters: {'salon_id': salon.id},
    );
    final url = Uri.parse(
      '${AppConfig.publicSiteBaseUrl}/pages/${salon.id}/offres.html',
    );
    final offersHtml = await dio.get<String>(
      url.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final offers = const WebsiteOffersPageParser().parse(
      salonId: salon.id,
      pageUrl: url,
      html: offersHtml.data!,
    );
    result.add({
      'salon': salon.id,
      'address': salon.address,
      'phone': salon.phone,
      'images': salon.images,
      'hours': salon.openingHours,
      'faqCount': salon.questions.length,
      'storyCharacters': salon.story.length,
      'team': profiles,
      'bookableBarbers': bookable.data!.map((e) => (e as Map)['name']).toList(),
      'services': services.data!
          .map(
            (e) => {
              'id': (e as Map)['id'],
              'name': e['name'],
              'priceCents': e['price'],
            },
          )
          .toList(),
      'offers': offers.sections
          .map(
            (section) => {
              'headline': section.headline,
              'details': section.details,
              'type': section.type.name,
            },
          )
          .toList(),
    });
  }
  if (arguments.contains('--check-media')) {
    for (final url in {...portraits, ...salons.expand((s) => s.images)}) {
      final response = await dio.head<dynamic>(url);
      final type = response.headers.value('content-type') ?? '';
      if (!type.startsWith('image/'))
        throw StateError('Not an image: $url ($type)');
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
