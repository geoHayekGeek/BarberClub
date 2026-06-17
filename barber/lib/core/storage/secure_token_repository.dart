import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_repository.dart';

/// Secure token storage implementation using flutter_secure_storage
class SecureTokenRepository
    implements TokenRepository, ReservationTokenRepository {
  SecureTokenRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _reservationAccessTokenKey = 'reservation_access_token';
  static const String _reservationRefreshTokenKey = 'reservation_refresh_token';

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  @override
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  @override
  Future<void> saveReservationAccessToken(String token) async {
    await _storage.write(key: _reservationAccessTokenKey, value: token);
  }

  @override
  Future<String?> getReservationAccessToken() async {
    return await _storage.read(key: _reservationAccessTokenKey);
  }

  @override
  Future<void> saveReservationRefreshToken(String token) async {
    await _storage.write(key: _reservationRefreshTokenKey, value: token);
  }

  @override
  Future<String?> getReservationRefreshToken() async {
    return await _storage.read(key: _reservationRefreshTokenKey);
  }

  @override
  Future<void> clearReservationTokens() async {
    await Future.wait([
      _storage.delete(key: _reservationAccessTokenKey),
      _storage.delete(key: _reservationRefreshTokenKey),
    ]);
  }

  @override
  Future<bool> hasReservationTokens() async {
    final accessToken = await getReservationAccessToken();
    final refreshToken = await getReservationRefreshToken();
    return accessToken != null && refreshToken != null;
  }
}
