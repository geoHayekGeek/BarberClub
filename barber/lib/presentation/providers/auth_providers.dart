import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/user.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../core/storage/token_repository.dart';
import '../../core/storage/secure_token_repository.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/fcm_service.dart';
import '../../domain/repositories/reservation_auth_repository.dart';
import 'reservation_auth_providers.dart';

/// Auth status enum
enum AuthStatus { unauthenticated, authenticating, authenticated, error }

/// Auth state
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({required this.status, this.user, this.errorMessage});

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

/// FCM service provider
final fcmServiceProvider = Provider<FcmService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final service = FcmService(dioClient: dioClient);
  ref.onDispose(service.dispose);
  return service;
});

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthController, AuthState>((
  ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  final tokenRepository = ref.watch(tokenRepositoryProvider);
  final fcmService = ref.watch(fcmServiceProvider);
  final reservationAuthRepository = ref.watch(
    reservationAuthRepositoryProvider,
  );
  return AuthController(
    ref: ref,
    authRepository: authRepository,
    tokenRepository: tokenRepository,
    fcmService: fcmService,
    reservationAuthRepository: reservationAuthRepository,
  );
});

/// Auth controller
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required Ref ref,
    required AuthRepository authRepository,
    required TokenRepository tokenRepository,
    required FcmService fcmService,
    required ReservationAuthRepository reservationAuthRepository,
  }) : _authRepository = authRepository,
       _tokenRepository = tokenRepository,
       _fcmService = fcmService,
       _reservationAuthRepository = reservationAuthRepository,
       _ref = ref,
       super(const AuthState(status: AuthStatus.unauthenticated));

  final Ref _ref;
  final AuthRepository _authRepository;
  final TokenRepository _tokenRepository;
  final FcmService _fcmService;
  final ReservationAuthRepository _reservationAuthRepository;

  /// Bootstrap session: check if user is already logged in
  Future<void> bootstrapSession() async {
    state = state.copyWith(status: AuthStatus.authenticating);

    try {
      final hasTokens = await _tokenRepository.hasTokens();
      if (hasTokens) {
        final user = await _authRepository.getCurrentUser();
        state = AuthState(status: AuthStatus.authenticated, user: user);
        await _registerPushTokenBestEffort();
        return;
      }
    } catch (e) {
      // Clear invalid app tokens, then fall back to the reservation session.
      await _tokenRepository.clearTokens();
    }

    try {
      final reservationSession = await _reservationAuthRepository
          .restoreSession();
      if (reservationSession != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: _reservationSessionToAppUser(reservationSession.user),
        );
        return;
      }
    } catch (_) {
      // Reservation restore is best effort.
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
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
      if (email != null && email.trim().isNotEmpty) {
        final reservationSession = await _reservationAuthRepository.login(
          email: email.trim(),
          password: password,
        );
        await _handleReservationAuthenticated(
          reservationSession: reservationSession,
          email: email.trim(),
          password: password,
        );
        return;
      }

      final loginResult = await _loginAndSyncReservationSession(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      await _tokenRepository.saveAccessToken(loginResult.response.accessToken);
      await _tokenRepository.saveRefreshToken(
        loginResult.response.refreshToken,
      );

      _ref
          .read(reservationSessionProvider.notifier)
          .setSession(loginResult.reservationSession);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: loginResult.response.user,
      );
      await _registerPushTokenBestEffort();
    } catch (e) {
      await _rollbackAppLogin();
      await _ref.read(reservationSessionProvider.notifier).clearSession();
      final errorMessage = e is ApiError
          ? e.getFriendlyMessage()
          : 'Une erreur est survenue.';
      state = AuthState(status: AuthStatus.error, errorMessage: errorMessage);
    }
  }

  /// Register a new user
  Future<void> register({
    required String email,
    required String phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
      clearError: true,
    );

    try {
      final reservationSession = await _reservationAuthRepository.register(
        firstName: firstName,
        lastName: lastName,
        phone: phoneNumber,
        email: email,
        password: password,
      );
      await _handleReservationAuthenticated(
        reservationSession: reservationSession,
        email: email,
        password: password,
      );
      return;
    } catch (e) {
      try {
        final response = await _authRepository.register(
          email: email,
          phoneNumber: phoneNumber,
          password: password,
          fullName: '$firstName $lastName'.trim(),
        );

        // Save tokens
        await _tokenRepository.saveAccessToken(response.accessToken);
        await _tokenRepository.saveRefreshToken(response.refreshToken);

        final reservationSession = await _reservationAuthRepository
            .ensureSessionFromAppAuth(
              email: email,
              password: password,
              phone: phoneNumber,
              firstName: firstName,
              lastName: lastName,
            );
        _ref
            .read(reservationSessionProvider.notifier)
            .setSession(reservationSession);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        await _registerPushTokenBestEffort();
      } catch (innerError) {
        await _rollbackAppRegistration(password: password);
        await _ref.read(reservationSessionProvider.notifier).clearSession();
        final errorMessage = innerError is ApiError
            ? innerError.getFriendlyMessage()
            : 'Une erreur est survenue.';
        state = AuthState(status: AuthStatus.error, errorMessage: errorMessage);
      }
    }
  }

  Future<void> _registerPushTokenBestEffort() async {
    try {
      await _fcmService.registerWithBackend();
    } catch (_) {
      // Push registration is best effort and should not block auth success.
    }
  }

  Future<void> _handleReservationAuthenticated({
    required ReservationSession reservationSession,
    required String email,
    required String password,
  }) async {
    _ref
        .read(reservationSessionProvider.notifier)
        .setSession(reservationSession);
    state = AuthState(
      status: AuthStatus.authenticated,
      user: _reservationSessionToAppUser(reservationSession.user),
    );

    unawaited(
      _syncAppSessionBestEffort(
        email: email,
        password: password,
        reservationSession: reservationSession,
      ),
    );
  }

  Future<void> _syncAppSessionBestEffort({
    required String email,
    required String password,
    required ReservationSession reservationSession,
  }) async {
    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );
      await _tokenRepository.saveAccessToken(response.accessToken);
      await _tokenRepository.saveRefreshToken(response.refreshToken);
      state = AuthState(status: AuthStatus.authenticated, user: response.user);
      await _registerPushTokenBestEffort();
      return;
    } on ApiError catch (error) {
      if (!_shouldFallbackToReservationSync(error, email)) {
        return;
      }
    } catch (_) {
      return;
    }

    try {
      final response = await _authRepository.register(
        email: reservationSession.user.email,
        phoneNumber: reservationSession.user.phone,
        password: password,
        fullName: reservationSession.user.fullName.isEmpty
            ? null
            : reservationSession.user.fullName,
      );
      await _tokenRepository.saveAccessToken(response.accessToken);
      await _tokenRepository.saveRefreshToken(response.refreshToken);
      state = AuthState(status: AuthStatus.authenticated, user: response.user);
      await _registerPushTokenBestEffort();
    } catch (_) {
      // Best effort only.
    }
  }

  User _reservationSessionToAppUser(ReservationClientProfile profile) {
    final fullName = profile.fullName.trim();
    return User(
      id: profile.id,
      email: profile.email,
      phoneNumber: profile.phone,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }

  Future<({AuthResponse response, ReservationSession reservationSession})>
  _loginAndSyncReservationSession({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _authRepository.login(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      final reservationSession = await _reservationAuthRepository
          .ensureSessionFromAppAuth(
            email: response.user.email,
            password: password,
            phone: response.user.phoneNumber,
            fullName: response.user.fullName,
          );
      return (response: response, reservationSession: reservationSession);
    } on ApiError catch (error) {
      if (!_shouldFallbackToReservationSync(error, email)) {
        rethrow;
      }

      final normalizedEmail = email?.trim();
      if (normalizedEmail == null || normalizedEmail.isEmpty) {
        rethrow;
      }

      final reservationSession = await _reservationAuthRepository.login(
        email: normalizedEmail,
        password: password,
      );

      final appFullName = reservationSession.user.fullName;
      final response = await _authRepository.register(
        email: reservationSession.user.email,
        phoneNumber: reservationSession.user.phone,
        password: password,
        fullName: appFullName.isEmpty ? null : appFullName,
      );

      return (response: response, reservationSession: reservationSession);
    }
  }

  bool _shouldFallbackToReservationSync(ApiError error, String? email) {
    final normalizedEmail = email?.trim() ?? '';
    if (normalizedEmail.isEmpty) {
      return false;
    }

    return switch (error.code) {
      'UNAUTHORIZED' || 'INVALID_CREDENTIALS' || 'NOT_FOUND' => true,
      _ => false,
    };
  }

  Future<void> _rollbackAppLogin() async {
    try {
      final refreshToken = await _tokenRepository.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _authRepository.logout(refreshToken);
      }
    } catch (_) {
      // Ignore rollback errors and clear the local session below.
    } finally {
      await _tokenRepository.clearTokens();
    }
  }

  Future<void> _rollbackAppRegistration({required String password}) async {
    try {
      await _authRepository.deleteAccount(password: password);
    } catch (_) {
      // Ignore rollback errors and clear the local session below.
    } finally {
      await _tokenRepository.clearTokens();
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
      state = AuthState(status: AuthStatus.error, errorMessage: errorMessage);
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
      state = AuthState(status: AuthStatus.error, errorMessage: errorMessage);
    }
  }

  // --- NEW METHODS START ---

  /// Update profile details
  Future<void> updateProfile({
    String? email,
    String? phoneNumber,
    String? fullName,
  }) async {
    // We intentionally do NOT set global 'authenticating' status
    // to allow the UI to handle loading locally (e.g., button spinner)
    // or you can add a separate loading state field if preferred.
    try {
      final updatedUser = await _authRepository.updateProfile(
        email: email,
        phoneNumber: phoneNumber,
        fullName: fullName,
      );

      // Immediately update local state with new user info
      state = state.copyWith(user: updatedUser);

      final nameParts = _splitFullName(updatedUser.fullName);
      if (nameParts != null || (email != null && email.trim().isNotEmpty)) {
        try {
          final updatedReservationUser = await _reservationAuthRepository
              .updateProfile(
                firstName: nameParts?.$1,
                lastName: nameParts?.$2,
                email: updatedUser.email,
              );
          _ref
              .read(reservationSessionProvider.notifier)
              .updateUser(updatedReservationUser);
        } catch (_) {
          // Website profile sync is best effort for secondary edits.
        }
      }
    } catch (e) {
      // We rethrow so the UI (CompteScreen) can catch it and show a SnackBar
      rethrow;
    }
  }

  /// Update user avatar.
  Future<void> updateAvatar({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    try {
      final updatedUser = await _authRepository.updateAvatar(
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      state = state.copyWith(user: updatedUser);
    } catch (e) {
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _authRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- NEW METHODS END ---

  (String, String)? _splitFullName(String? fullName) {
    final normalized = fullName?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return null;
    }

    return (parts.first, parts.skip(1).join(' '));
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
      await _ref.read(reservationSessionProvider.notifier).logout();
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

  /// Delete authenticated account permanently then clear local session.
  Future<void> deleteAccount({required String password}) async {
    await _authRepository.deleteAccount(password: password);
    await _ref.read(reservationSessionProvider.notifier).clearSession();
    await _tokenRepository.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
