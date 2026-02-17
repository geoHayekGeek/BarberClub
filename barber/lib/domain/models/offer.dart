class Offer {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int price;
  final int durationMinutes;
  final String salonId;

  const Offer({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.price,
    required this.durationMinutes,
    required this.salonId,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      salonId: json['salonId'] as String? ?? '',
    );
  }
}