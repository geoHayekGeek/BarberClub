/// Client-side promotion (feed item from GET /api/v1/offers).
class ClientOffer {
  final String id;
  final String type;
  final String title;
  final String? description;
  final String discountType;
  final int discountValue;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? maxSpots;
  final int spotsTaken;
  final String? imageUrl;
  final List<String> applicableServices;

  const ClientOffer({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.startsAt,
    this.endsAt,
    this.maxSpots,
    required this.spotsTaken,
    this.imageUrl,
    required this.applicableServices,
  });

  factory ClientOffer.fromJson(Map<String, dynamic> json) {
    final startsAtRaw = json['startsAt'] ?? json['starts_at'];
    final endsAtRaw = json['endsAt'] ?? json['ends_at'];
    final applicableRaw = json['applicableServices'] ?? json['applicable_services'];
    return ClientOffer(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'event',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      discountType: json['discountType'] as String? ?? json['discount_type'] as String? ?? 'percentage',
      discountValue: (json['discountValue'] ?? json['discount_value'] ?? 0) as int,
      startsAt: startsAtRaw != null
          ? DateTime.tryParse(startsAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      endsAt: endsAtRaw != null ? DateTime.tryParse(endsAtRaw.toString()) : null,
      maxSpots: (json['maxSpots'] ?? json['max_spots']) as int?,
      spotsTaken: (json['spotsTaken'] ?? json['spots_taken'] ?? 0) as int,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      applicableServices: applicableRaw is List
          ? (applicableRaw).map((e) => e.toString()).toList()
          : [],
    );
  }

  bool get isEvent => type == 'event';
  bool get isFlash => type == 'flash';
  bool get isPack => type == 'pack';
  bool get isPermanent => type == 'permanent';

  /// QR activation is only exposed in the UI for event and flash (legacy product rules).
  bool get supportsQrActivation => isEvent || isFlash;

  /// Offer has ended ([endsAt] on or before [now]).
  bool isExpired(DateTime now) {
    if (endsAt == null) return false;
    return !endsAt!.isAfter(now);
  }

  /// Currently valid in the public feed: started and not expired.
  bool isCurrentlyAvailable(DateTime now) {
    if (isExpired(now)) return false;
    return !startsAt.isAfter(now);
  }

  /// Scheduled for a future start and not expired.
  bool isUpcoming(DateTime now) {
    if (isExpired(now)) return false;
    return startsAt.isAfter(now);
  }

  String get discountBadge {
    if (discountType == 'percentage') return '-$discountValue%';
    if (discountType == 'fixed') return '-${discountValue}€';
    return 'Offert';
  }
}
