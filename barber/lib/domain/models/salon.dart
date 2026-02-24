/// Salon model.
/// fromJson supports backend response; field names match API.
class Salon {
  final String id;
  final String name;
  final String city;
  final String descriptionShort;
  final String descriptionLong;
  final String address;
  final List<String> images;
  final String openingHours;
  final List<String> services;
  final String? timifyUrl;
  final String? phone;

  const Salon({
    required this.id,
    required this.name,
    required this.city,
    required this.descriptionShort,
    required this.descriptionLong,
    required this.address,
    required this.images,
    required this.openingHours,
    required this.services,
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

    // Backend sends openingHoursText (human-readable) and/or openingHours (object); prefer text for display
    final openingHoursText = json['openingHoursText'] as String?;
    final Object? rawHours = json['openingHours'] ?? json['opening_hours'];
    String openingHoursStr = openingHoursText ?? '';
    if (openingHoursStr.isEmpty && rawHours is String) {
      openingHoursStr = rawHours;
    }

    return Salon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      descriptionShort: description,
      descriptionLong: longDesc,
      address: json['address'] as String? ?? '',
      images: imagesList,
      openingHours: openingHoursStr,
      services:
          (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      timifyUrl: json['timifyUrl'] as String? ?? json['timify_url'] as String?,
      phone: json['phone'] as String?,
    );
  }

  /// First image URL for hero/cover; null if none.
  String? get imageUrl => images.isNotEmpty ? images.first : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'descriptionShort': descriptionShort,
      'descriptionLong': descriptionLong,
      'address': address,
      'images': images,
      'openingHours': openingHours,
      'services': services,
      'timifyUrl': timifyUrl,
      'phone': phone,
    };
  }
}
