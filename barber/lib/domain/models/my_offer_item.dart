/// User's activated offer (from GET /api/v1/client/offers).
class MyOfferItem {
  final String activationId;
  final String status;
  final DateTime activatedAt;
  final DateTime? expiresAt;
  final MyOfferOffer offer;

  const MyOfferItem({
    required this.activationId,
    required this.status,
    required this.activatedAt,
    this.expiresAt,
    required this.offer,
  });

  factory MyOfferItem.fromJson(Map<String, dynamic> json) {
    final offerRaw = json['offer'] as Map<String, dynamic>? ?? {};
    final activatedRaw = json['activatedAt'] ?? json['activated_at'];
    final expiresRaw = json['expiresAt'] ?? json['expires_at'];
    return MyOfferItem(
      activationId: json['activationId'] as String? ?? json['activation_id'] as String? ?? '',
      status: json['status'] as String? ?? 'activated',
      activatedAt: activatedRaw != null
          ? DateTime.tryParse(activatedRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw.toString()) : null,
      offer: MyOfferOffer.fromJson(offerRaw),
    );
  }

  bool get isActivated => status == 'activated';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';
}

class MyOfferOffer {
  final String id;
  final String type;
  final String title;
  final String? description;
  final int discountValue;
  final DateTime? endsAt;

  const MyOfferOffer({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.discountValue,
    this.endsAt,
  });

  factory MyOfferOffer.fromJson(Map<String, dynamic> json) {
    final endsRaw = json['endsAt'] ?? json['ends_at'];
    return MyOfferOffer(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'event',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      discountValue: (json['discountValue'] ?? json['discount_value'] ?? 0) as int,
      endsAt: endsRaw != null ? DateTime.tryParse(endsRaw.toString()) : null,
    );
  }
}
