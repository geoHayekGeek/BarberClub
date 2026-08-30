import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_token_repository.dart';
import '../../core/storage/token_repository.dart';
import '../../data/repositories/reservation_auth_repository_impl.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/repositories/reservation_auth_repository.dart';

enum ReservationSessionStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class ReservationSessionState {
  const ReservationSessionState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  final ReservationSessionStatus status;
  final ReservationClientProfile? user;
  final String? errorMessage;

  ReservationSessionState copyWith({
    ReservationSessionStatus? status,
    ReservationClientProfile? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return ReservationSessionState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final reservationTokenRepositoryProvider = Provider<ReservationTokenRepository>(
  (ref) {
    return SecureTokenRepository();
  },
);

final reservationAuthRepositoryProvider = Provider<ReservationAuthRepository>((
  ref,
) {
  final tokenRepository = ref.watch(reservationTokenRepositoryProvider);
  return ReservationAuthRepositoryImpl(tokenRepository: tokenRepository);
});

final reservationSessionProvider =
    StateNotifierProvider<
      ReservationSessionController,
      ReservationSessionState
    >((ref) {
      final repository = ref.watch(reservationAuthRepositoryProvider);
      return ReservationSessionController(repository: repository);
    });

class ReservationSessionController
    extends StateNotifier<ReservationSessionState> {
  ReservationSessionController({required ReservationAuthRepository repository})
    : _repository = repository,
      super(
        const ReservationSessionState(
          status: ReservationSessionStatus.unauthenticated,
        ),
      );

  final ReservationAuthRepository _repository;

  /// The single in-flight bootstrap, shared by every caller.
  Future<ReservationSession?>? _bootstrap;

  Future<void> bootstrapSession() => ensureBootstrapped().then((_) {});

  /// Restores the reservation session exactly once, no matter how many callers
  /// ask. Previously this controller and [AuthController] each called
  /// restoreSession() in parallel, which raced on the rotating refresh token.
  Future<ReservationSession?> ensureBootstrapped() {
    final existing = _bootstrap;
    if (existing != null) return existing;

    final future = _bootstrapOnce();
    _bootstrap = future;
    return future.whenComplete(() {
      _bootstrap = null;
    });
  }

  Future<ReservationSession?> _bootstrapOnce() async {
    state = state.copyWith(
      status: ReservationSessionStatus.authenticating,
      clearError: true,
    );

    try {
      final session = await _repository.restoreSession();
      if (session == null) {
        state = const ReservationSessionState(
          status: ReservationSessionStatus.unauthenticated,
        );
        return null;
      }

      state = ReservationSessionState(
        status: ReservationSessionStatus.authenticated,
        user: session.user,
      );
      return session;
    } catch (e) {
      // Do NOT clear the session here: an unexpected error is not proof the
      // credentials are invalid, and wiping them locked users out for good.
      debugPrint('[reservation] bootstrap failed, keeping tokens: $e');
      state = const ReservationSessionState(
        status: ReservationSessionStatus.unauthenticated,
      );
      return null;
    }
  }

  void setSession(ReservationSession session) {
    state = ReservationSessionState(
      status: ReservationSessionStatus.authenticated,
      user: session.user,
    );
  }

  void updateUser(ReservationClientProfile user) {
    final createdAt = user.createdAt ?? state.user?.createdAt;
    state = ReservationSessionState(
      status: ReservationSessionStatus.authenticated,
      user: ReservationClientProfile(
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        email: user.email,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      state = const ReservationSessionState(
        status: ReservationSessionStatus.unauthenticated,
      );
    }
  }

  Future<void> clearSession() async {
    await _repository.clearSession();
    state = const ReservationSessionState(
      status: ReservationSessionStatus.unauthenticated,
    );
  }

  void setError(String message) {
    state = ReservationSessionState(
      status: ReservationSessionStatus.error,
      errorMessage: message,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
