/// Salon model.
/// fromJson supports backend response; field names match API.
class Salon {
  const Salon({
    required this.id,
    required this.name,
    required this.city,
    required this.descriptionShort,
    required this.descriptionLong,
    required this.address,
    required this.openingHours,
    required this.images,
    required this.services,
    this.websiteId,
    this.location,
    this.openingHoursStructured,
    this.timifyUrl,
    this.phone,
  });

  /// Backend may use camelCase, snake_case, or single "description"; all supported.
  /// Backend v2 returns imageUrl + gallery instead of images, and openingHours as object; we normalize.
  factory Salon.fromJson(Map<String, dynamic> json) {
    final description = json['description'] as String? ??
        json['descriptionShort'] as String? ??
        json['description_short'] as String? ??
        '';
    final longDesc = json['descriptionLong'] as String? ??
        json['description_long'] as String? ??
        description;
    final websiteId = json['websiteId'] as String? ??
        json['website_id'] as String?;

    List<String> imagesList = const [];
    if (json['images'] is List) {
      imagesList = (json['images'] as List<dynamic>)
          .map((e) => e is String ? e : e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['imageUrl'] != null || json['gallery'] is List) {
      final hero = json['imageUrl'] as String? ?? json['image_url'] as String?;
      final gallery = (json['gallery'] as List<dynamic>?)
              ?.map((e) => e is String ? e : e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
      if (hero != null && hero.isNotEmpty) {
        imagesList = [hero, ...gallery];
      } else {
        imagesList = gallery;
      }
    }

    // Backend sends openingHoursText (human-readable) and openingHours (object); store both
    final openingHoursText = json['openingHoursText'] as String?;
    final Object? rawHours = json['openingHours'] ?? json['opening_hours'];
    String openingHoursStr = openingHoursText ?? '';
    if (openingHoursStr.isEmpty && rawHours is String) {
      openingHoursStr = rawHours;
    }
    final Map<String, dynamic>? structured = (rawHours is Map<String, dynamic>) ? rawHours : null;

    return Salon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      websiteId: websiteId,
      city: json['city'] as String? ?? '',
      descriptionShort: description,
      descriptionLong: longDesc,
      location: json['location'] as String?, 
      address: json['address'] as String? ?? '',
      images: imagesList,
      openingHours: openingHoursStr,
      openingHoursStructured: structured,
      services:
          (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      timifyUrl: json['timifyUrl'] as String? ?? json['timify_url'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String id;
  final String name;
  final String? websiteId;
  final String city;
  final String descriptionShort;
  final String descriptionLong;
  final String? location;
  final String address;
  final List<String> images;
  final String openingHours;
  /// Structured hours from API (monday: { open, close, closed }, ...). Used for display when present.
  final Map<String, dynamic>? openingHoursStructured;
  final List<String> services;
  final String? timifyUrl;
  final String? phone;

  /// First image URL for hero/cover; null if none.
  String? get imageUrl => images.isNotEmpty ? images.first : null;

  /// Public website slug used by the reservation backend.
  /// Falls back to the known salon slugs so the reservation flow stays resilient
  /// even while local data is still being backfilled.
  String get reservationSalonId {
    final normalizedWebsiteId = websiteId?.trim().toLowerCase();
    if (normalizedWebsiteId != null && normalizedWebsiteId.isNotEmpty) {
      return normalizedWebsiteId;
    }

    final normalizedCity = city.trim().toLowerCase();
    if (normalizedCity.contains('grenoble')) return 'grenoble';
    if (normalizedCity.contains('meylan')) return 'meylan';

    final normalizedName = name.trim().toLowerCase();
    if (normalizedName.contains('grenoble')) return 'grenoble';
    if (normalizedName.contains('meylan')) return 'meylan';

    return id;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (websiteId != null) 'websiteId': websiteId,
      'city': city,
      'descriptionShort': descriptionShort,
      'descriptionLong': descriptionLong,
      'location': location,
      'address': address,
      'images': images,
      'openingHours': openingHours,
      if (openingHoursStructured != null) 'openingHoursStructured': openingHoursStructured,
      'services': services,
      'timifyUrl': timifyUrl,
      'phone': phone,
    };
  }
}
