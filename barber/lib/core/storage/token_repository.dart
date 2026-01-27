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
