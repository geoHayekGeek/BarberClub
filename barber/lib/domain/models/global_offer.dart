/// Global promotion (not salon-based)
class GlobalOffer {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? discount;
  final bool isActive;
  final DateTime createdAt;

  const GlobalOffer({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.discount,
    required this.isActive,
    required this.createdAt,
  });

  factory GlobalOffer.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    return GlobalOffer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      discount: (json['discount'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
