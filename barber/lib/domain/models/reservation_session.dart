import 'package:flutter/foundation.dart';

@immutable
class ReservationClientProfile {
  const ReservationClientProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    this.createdAt,
  });

  factory ReservationClientProfile.fromJson(Map<String, dynamic> json) {
    final createdAtRaw =
        json['created_at'] as String? ?? json['createdAt'] as String?;

    return ReservationClientProfile(
      id: json['id'] as String? ?? '',
      firstName:
          json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName:
          json['last_name'] as String? ?? json['lastName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      createdAt: createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final DateTime? createdAt;

  String get fullName => [
    firstName,
    lastName,
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
}

@immutable
class ReservationSession {
  const ReservationSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final ReservationClientProfile user;
}
