class ReservationBarber {
  const ReservationBarber({
    required this.id,
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.isGuest,
    required this.offDays,
    required this.workDates,
    required this.offDates,
    required this.guestDates,
    required this.contractStart,
    required this.contractEnd,
  });

  factory ReservationBarber.fromJson(Map<String, dynamic> json) {
    return ReservationBarber(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      isGuest: _asBool(json['is_guest']) ?? false,
      offDays: _asIntList(json['off_days']),
      workDates: _asStringList(json['work_dates']),
      offDates: _asStringList(json['off_dates']),
      guestDates: _asStringList(json['guest_dates']),
      contractStart:
          json['contract_start'] as String? ?? json['contractStart'] as String?,
      contractEnd:
          json['contract_end'] as String? ?? json['contractEnd'] as String?,
    );
  }

  final String id;
  final String name;
  final String role;
  final String? photoUrl;
  final bool isGuest;
  final List<int> offDays;
  final List<String> workDates;
  final List<String> offDates;
  final List<String> guestDates;
  final String? contractStart;
  final String? contractEnd;

  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;
}

class ReservationService {
  const ReservationService({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.durationMinutes,
    required this.durationSaturdayMinutes,
    required this.description,
    required this.color,
    required this.customDurationMinutes,
  });

  factory ReservationService.fromJson(Map<String, dynamic> json) {
    return ReservationService(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCents: _asInt(json['price']) ?? 0,
      durationMinutes: _asInt(json['duration']) ?? 0,
      durationSaturdayMinutes: _asInt(
        json['duration_saturday'] ?? json['durationSaturday'],
      ),
      description: json['description'] as String? ?? '',
      color: json['color'] as String?,
      customDurationMinutes: _asInt(
        json['custom_duration'] ?? json['customDuration'],
      ),
    );
  }

  final String id;
  final String name;
  final int priceCents;
  final int durationMinutes;
  final int? durationSaturdayMinutes;
  final String description;
  final String? color;
  final int? customDurationMinutes;

  int get effectiveDurationMinutes => customDurationMinutes ?? durationMinutes;

  int durationForDate(DateTime date) {
    if (customDurationMinutes != null) {
      return customDurationMinutes!;
    }
    if (date.weekday == DateTime.saturday && durationSaturdayMinutes != null) {
      return durationSaturdayMinutes!;
    }
    return durationMinutes;
  }
}

class ReservationSlot {
  const ReservationSlot({
    required this.time,
    required this.barberId,
    required this.barberName,
  });

  factory ReservationSlot.fromJson(Map<String, dynamic> json) {
    return ReservationSlot(
      time: json['time'] as String? ?? '',
      barberId:
          json['barber_id'] as String? ?? json['barberId'] as String? ?? '',
      barberName:
          json['barber_name'] as String? ?? json['barberName'] as String? ?? '',
    );
  }

  final String time;
  final String barberId;
  final String barberName;
}

class ReservationAlternativeBarber {
  const ReservationAlternativeBarber({
    required this.barberId,
    required this.barberName,
    required this.slotCount,
    required this.sampleTimes,
  });

  factory ReservationAlternativeBarber.fromJson(Map<String, dynamic> json) {
    return ReservationAlternativeBarber(
      barberId:
          json['barber_id'] as String? ?? json['barberId'] as String? ?? '',
      barberName:
          json['barber_name'] as String? ?? json['barberName'] as String? ?? '',
      slotCount: _asInt(json['slot_count'] ?? json['slotCount']) ?? 0,
      sampleTimes: _asStringList(json['sample_times'] ?? json['sampleTimes']),
    );
  }

  final String barberId;
  final String barberName;
  final int slotCount;
  final List<String> sampleTimes;
}

class ReservationMonthAvailability {
  const ReservationMonthAvailability({
    required this.total,
    required this.status,
    required this.alternatives,
  });

  factory ReservationMonthAvailability.fromJson(Map<String, dynamic> json) {
    final alternativesRaw = json['alternatives'];
    final alternatives = alternativesRaw is List
        ? alternativesRaw
              .whereType<Map<String, dynamic>>()
              .map(ReservationAlternativeBarber.fromJson)
              .toList()
        : const <ReservationAlternativeBarber>[];

    return ReservationMonthAvailability(
      total: _asInt(json['total']) ?? 0,
      status: json['status'] as String? ?? 'full',
      alternatives: alternatives,
    );
  }

  final int total;
  final String status;
  final List<ReservationAlternativeBarber> alternatives;

  bool get isFull => status == 'full';

  bool get hasAlternatives => alternatives.isNotEmpty;
}

class ReservationBooking {
  const ReservationBooking({
    required this.id,
    required this.clientId,
    required this.barberId,
    required this.barberName,
    required this.barberPhotoUrl,
    required this.serviceId,
    required this.serviceName,
    required this.salonId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.priceCents,
    required this.status,
    required this.cancelToken,
    required this.source,
    required this.createdAt,
    required this.hasAccount,
  });

  factory ReservationBooking.fromJson(Map<String, dynamic> json) {
    return ReservationBooking(
      id: json['id'] as String? ?? '',
      clientId:
          json['client_id'] as String? ?? json['clientId'] as String? ?? '',
      barberId:
          json['barber_id'] as String? ?? json['barberId'] as String? ?? '',
      barberName:
          json['barber_name'] as String? ?? json['barberName'] as String? ?? '',
      barberPhotoUrl:
          json['barber_photo'] as String? ?? json['barberPhoto'] as String?,
      serviceId:
          json['service_id'] as String? ?? json['serviceId'] as String? ?? '',
      serviceName:
          json['service_name'] as String? ??
          json['serviceName'] as String? ??
          '',
      salonId: json['salon_id'] as String? ?? json['salonId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime:
          json['start_time'] as String? ?? json['startTime'] as String? ?? '',
      endTime: json['end_time'] as String? ?? json['endTime'] as String? ?? '',
      priceCents: _asInt(json['price']) ?? 0,
      status: json['status'] as String? ?? 'confirmed',
      cancelToken:
          json['cancel_token'] as String? ??
          json['cancelToken'] as String? ??
          '',
      source: json['source'] as String? ?? 'online',
      createdAt:
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
      hasAccount: _asBool(json['has_account']) ?? false,
    );
  }

  final String id;
  final String clientId;
  final String barberId;
  final String barberName;
  final String? barberPhotoUrl;
  final String serviceId;
  final String serviceName;
  final String salonId;
  final String date;
  final String startTime;
  final String endTime;
  final int priceCents;
  final String status;
  final String cancelToken;
  final String source;
  final String createdAt;
  final bool hasAccount;
}

class ReservationClientBookingsPage {
  const ReservationClientBookingsPage({
    required this.upcoming,
    required this.past,
  });

  factory ReservationClientBookingsPage.fromJson(Map<String, dynamic> json) {
    return ReservationClientBookingsPage(
      upcoming: _parseBookings(json['upcoming']),
      past: _parseBookings(json['past']),
    );
  }

  final List<ReservationBooking> upcoming;
  final List<ReservationBooking> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;

  ReservationBooking? get nextUpcoming =>
      upcoming.isNotEmpty ? upcoming.first : null;

  List<ReservationBooking> get allBookings => [...upcoming, ...past];
}

List<ReservationBooking> _parseBookings(dynamic raw) {
  if (raw is! List) {
    return const [];
  }

  return raw
      .whereType<Map<String, dynamic>>()
      .map(ReservationBooking.fromJson)
      .toList(growable: false);
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_asInt).whereType<int>().toList(growable: false);
}
