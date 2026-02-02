import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../core/storage/token_repository.dart';
import '../../core/storage/secure_token_repository.dart';
import '../../core/network/dio_client.dart';

/// Auth status enum
enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

/// Auth state
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Token repository provider
final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  return SecureTokenRepository();
});

/// Dio client provider
final dioClientProvider = Provider<DioClient>((ref) {
  final tokenRepository = ref.watch(tokenRepositoryProvider);
  return DioClient(tokenRepository: tokenRepository);
});

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepositoryImpl(dioClient: dioClient);
});

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final tokenRepository = ref.watch(tokenRepositoryProvider);
    return AuthController(
      authRepository: authRepository,
      tokenRepository: tokenRepository,
    );
  },
);

/// Auth controller
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository authRepository,
    required TokenRepository tokenRepository,
  })  : _authRepository = authRepository,
        _tokenRepository = tokenRepository,
        super(
          const AuthState(status: AuthStatus.unauthenticated),
        );

  final AuthRepository _authRepository;
  final TokenRepository _tokenRepository;

  /// Bootstrap session: check if user is already logged in
  Future<void> bootstrapSession() async {
    state = state.copyWith(status: AuthStatus.authenticating);

    try {
      final hasTokens = await _tokenRepository.hasTokens();
      if (!hasTokens) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = await _authRepository.getCurrentUser();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      // Clear invalid tokens
      await _tokenRepository.clearTokens();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Login with email or phone number
  Future<void> login({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
      clearError: true,
    );

    try {
      final response = await _authRepository.login(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      // Save tokens
      await _tokenRepository.saveAccessToken(response.accessToken);
      await _tokenRepository.saveRefreshToken(response.refreshToken);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } catch (e) {
      final errorMessage = e is ApiError
          ? e.getFriendlyMessage()
          : 'Une erreur est survenue.';
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  /// Register a new user
  Future<void> register({
    required String email,
    required String phoneNumber,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
      clearError: true,
    );

    try {
      final response = await _authRepository.register(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        fullName: fullName,
      );

      // Save tokens
      await _tokenRepository.saveAccessToken(response.accessToken);
      await _tokenRepository.saveRefreshToken(response.refreshToken);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } catch (e) {
      final errorMessage = e is ApiError
          ? e.getFriendlyMessage()
          : 'Une erreur est survenue.';
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  /// Forgot password
  Future<void> forgotPassword(String email) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
      clearError: true,
    );

    try {
      await _authRepository.forgotPassword(email);
      // On success: set to unauthenticated, clear error
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
    } catch (e) {
      final errorMessage = e is ApiError
          ? e.getFriendlyMessage()
          : 'Une erreur est survenue. Veuillez réessayer.';
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  /// Reset password with OTP code
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
      clearError: true,
    );

    try {
      await _authRepository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      // On success: set to unauthenticated, clear error
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
    } catch (e) {
      final errorMessage = e is ApiError
          ? _getResetPasswordErrorMessage(e)
          : 'Une erreur est survenue.';
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  /// Get friendly error message for reset password
  String _getResetPasswordErrorMessage(ApiError error) {
    switch (error.code) {
      case 'CODE_INVALID':
        return 'Code incorrect.';
      case 'CODE_EXPIRED':
        return 'Code expiré. Demandez-en un nouveau.';
      case 'CODE_TOO_MANY_ATTEMPTS':
        return 'Trop de tentatives. Demandez un nouveau code.';
      case 'RATE_LIMITED':
        return 'Trop de demandes. Réessayez plus tard.';
      case 'VALIDATION_ERROR':
        return 'Mot de passe invalide.';
      case 'NETWORK_ERROR':
        return 'Problème de connexion. Réessayez.';
      default:
        return 'Une erreur est survenue.';
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final refreshToken = await _tokenRepository.getRefreshToken();
      if (refreshToken != null) {
        await _authRepository.logout(refreshToken);
      }
    } catch (e) {
      // Continue with logout even if API call fails
    } finally {
      await _tokenRepository.clearTokens();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
