import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';
part 'api_error.g.dart';

@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    required String code,
    required String message,
    @JsonKey(name: 'fields') Map<String, dynamic>? fields,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
  
  /// Parse from backend error response format
  /// { "error": { "code": "...", "message": "...", "fields": {...} } }
  factory ApiError.fromErrorResponse(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    if (error == null) {
      return const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Erreur inconnue',
      );
    }
    
    return ApiError(
      code: error['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error['message'] as String? ?? 'Erreur inconnue',
      fields: error['fields'] as Map<String, dynamic>?,
    );
  }
}

/// Extension for ApiError to add helper methods
extension ApiErrorExtension on ApiError {
  /// Get friendly French error message
  String getFriendlyMessage() {
    switch (code) {
      case 'UNAUTHORIZED':
      case 'INVALID_CREDENTIALS':
        return 'Identifiants incorrects.';
      case 'VALIDATION_ERROR':
        return 'Veuillez vérifier les informations saisies.';
      case 'INVALID_INPUT':
        return 'Adresse e-mail invalide.';
      case 'USER_ALREADY_EXISTS':
        // Check fields to see if email or phone is the issue
        if (fields != null) {
          if (fields!['email'] == true) {
            return 'Cet e-mail est déjà utilisé.';
          }
          if (fields!['phoneNumber'] == true) {
            return 'Ce numéro est déjà utilisé.';
          }
        }
        return 'Cet e-mail ou ce numéro est déjà utilisé.';
      case 'TOKEN_EXPIRED':
      case 'TOKEN_INVALID':
      case 'REFRESH_TOKEN_INVALID':
      case 'REFRESH_TOKEN_EXPIRED':
        return 'Session expirée. Veuillez vous reconnecter.';
      case 'NOT_FOUND':
        return 'Ressource introuvable.';
      case 'FORBIDDEN':
        return 'Accès refusé.';
      case 'NETWORK_ERROR':
        return 'Problème de connexion. Réessayez.';
      default:
        return message.isNotEmpty ? message : 'Une erreur est survenue.';
    }
  }
}
