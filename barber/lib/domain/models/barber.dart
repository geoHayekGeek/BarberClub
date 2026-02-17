/// Barber (coiffeur) model.
/// fromJson supports backend response; field names match API.
class Barber {

  const Barber({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.bio,
    this.experienceYears,
    this.age,
    this.origin,
    required this.level,
    required this.specialties,
    required this.images,
    this.videoUrl,
    required this.salons,
  });

  /// Backend may use "interests" for specialties; both supported.
  factory Barber.fromJson(Map<String, dynamic> json) {
    final specialties = (json['interests'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        (json['specialties'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [];
    final salonsList = (json['salons'] as List<dynamic>?)
        ?.map((e) => BarberSalon.fromJson(e as Map<String, dynamic>))
        .toList();
    return Barber(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? json['first_name'] as String? ?? '',
      lastName: json['lastName'] as String? ?? json['last_name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? (json['firstName'] as String?) ?? '',
      bio: json['bio'] as String? ?? '',
      experienceYears: json['experienceYears'] as int? ?? json['experience_years'] as int?,
      age: json['age'] as int?,
      origin: json['origin'] as String?,
      level: json['level'] as String? ?? 'senior',
      specialties: specialties,
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      videoUrl: json['videoUrl'] as String? ?? json['video_url'] as String?,
      salons: salonsList ?? [],
    );
  }
  final String id;
  final String firstName;
  final String lastName;
  final String displayName;
  final String bio;
  final int? experienceYears;
  final int? age;
  final String? origin;
  final String level;
  final List<String> specialties;
  final List<String> images;
  final String? videoUrl;
  final List<BarberSalon> salons;

  /// First image as main profile image; rest as gallery.
  String? get image => images.isNotEmpty ? images.first : null;
  List<String> get galleryImages => images.length > 1 ? images.sublist(1) : [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'bio': bio,
      'experienceYears': experienceYears,
      'age': age,
      'origin': origin,
      'level': level,
      'interests': specialties,
      'images': images,
      'videoUrl': videoUrl,
      'salons': salons.map((e) => e.toJson()).toList(),
    };
  }
}

class BarberSalon { 

  const BarberSalon({
    required this.id,
    required this.name,
    required this.city,
    this.timifyUrl,
  });

  factory BarberSalon.fromJson(Map<String, dynamic> json) {
    return BarberSalon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      timifyUrl: json['timifyUrl'] as String? ?? json['timify_url'] as String?, // <--- MAPPED HERE
    );
  }
  final String id;
  final String name;
  final String city;
  final String? timifyUrl;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'city': city,'timifyUrl': timifyUrl,};
}
