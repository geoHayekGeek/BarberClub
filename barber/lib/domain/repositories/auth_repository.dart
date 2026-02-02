import '../models/auth_response.dart';
import '../models/api_error.dart';
import '../models/user.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Register a new user
  /// 
  /// Throws [ApiError] on failure
  Future<AuthResponse> register({
    required String email,
    required String phoneNumber,
    required String password,
    String? fullName,
  });

  /// Login with email or phone number
  /// 
  /// Throws [ApiError] on failure
  Future<AuthResponse> login({
    String? email,
    String? phoneNumber,
    required String password,
  });

  /// Get current user profile
  /// 
  /// Throws [ApiError] on failure
  Future<User> getCurrentUser();

  /// Logout (revoke refresh token)
  /// 
  /// Throws [ApiError] on failure
  Future<void> logout(String refreshToken);

  /// Request password reset
  /// 
  /// Throws [ApiError] on failure
  Future<void> forgotPassword(String email);

  /// Reset password with OTP code
  /// 
  /// Throws [ApiError] on failure
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
