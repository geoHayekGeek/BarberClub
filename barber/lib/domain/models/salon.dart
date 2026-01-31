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
  });

  /// Backend may use camelCase, snake_case, or single "description"; all supported.
  factory Salon.fromJson(Map<String, dynamic> json) {
    final description = json['description'] as String? ??
        json['descriptionShort'] as String? ??
        json['description_short'] as String? ??
        '';
    final longDesc = json['descriptionLong'] as String? ??
        json['description_long'] as String? ??
        description;
    return Salon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      descriptionShort: description,
      descriptionLong: longDesc,
      address: json['address'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      openingHours: json['openingHours'] as String? ?? json['opening_hours'] as String? ?? '',
      services:
          (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
    );
  }

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
    };
  }
}
