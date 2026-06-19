/// Interface for secure token storage
abstract class TokenRepository {
  /// Save access token
  Future<void> saveAccessToken(String token);

  /// Get access token
  Future<String?> getAccessToken();

  /// Save refresh token
  Future<void> saveRefreshToken(String token);

  /// Get refresh token
  Future<String?> getRefreshToken();

  /// Clear all tokens
  Future<void> clearTokens();

  /// Check if user has tokens (is potentially logged in)
  Future<bool> hasTokens();
}

/// Separate secure storage contract for the website reservation session.
abstract class ReservationTokenRepository {
  /// Save the reservation access token.
  Future<void> saveReservationAccessToken(String token);

  /// Read the reservation access token.
  Future<String?> getReservationAccessToken();

  /// Save the reservation refresh token.
  Future<void> saveReservationRefreshToken(String token);

  /// Read the reservation refresh token.
  Future<String?> getReservationRefreshToken();

  /// Clear all reservation session tokens.
  Future<void> clearReservationTokens();

  /// Check whether a reservation session is present.
  Future<bool> hasReservationTokens();

  /// Save the cancel token for a specific reservation booking.
  Future<void> saveReservationBookingCancelToken({
    required String bookingId,
    required String cancelToken,
  });

  /// Read a cached cancel token for a specific reservation booking.
  Future<String?> getReservationBookingCancelToken(String bookingId);
}
