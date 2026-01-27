import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_tokens.dart';
import 'user.dart';

part 'auth_response.freezed.dart';
part 'auth_response.g.dart';

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required User user,
    required String accessToken,
    required String refreshToken,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

/// Extension for AuthResponse to add helper methods
extension AuthResponseExtension on AuthResponse {
  /// Convert to AuthTokens for storage
  AuthTokens toTokens() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
