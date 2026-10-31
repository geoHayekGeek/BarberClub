import 'dart:async';

import 'package:barber/core/services/fcm_service.dart';
import 'package:barber/core/storage/token_repository.dart';
import 'package:barber/domain/models/auth_response.dart';
import 'package:barber/domain/models/api_error.dart';
import 'package:barber/domain/models/reservation_session.dart';
import 'package:barber/domain/models/user.dart';
import 'package:barber/domain/repositories/auth_repository.dart';
import 'package:barber/domain/repositories/reservation_auth_repository.dart';
import 'package:barber/presentation/providers/auth_providers.dart';
import 'package:barber/presentation/providers/reservation_auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AppAuth extends Fake implements AuthRepository {
  int deletes = 0;
  final responses = <String, Completer<AuthResponse>>{};
  @override
  Future<AuthResponse> login({
    required String password,
    String? email,
    String? phoneNumber,
  }) {
    return (responses[email!] ??= Completer<AuthResponse>()).future;
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<AuthResponse> register({
    required String email,
    required String phoneNumber,
    required String password,
    String? fullName,
  }) async {
    throw const ApiError(
      code: 'EMAIL_ALREADY_EXISTS',
      message: 'Already registered',
    );
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    deletes++;
  }
}

class _ReservationAuth extends Fake implements ReservationAuthRepository {
  @override
  Future<ReservationSession> login({
    required String email,
    required String password,
  }) async => ReservationSession(
    accessToken: 'reservation-access',
    refreshToken: 'reservation-refresh',
    user: ReservationClientProfile(
      id: email,
      firstName: 'Test',
      lastName: 'Client',
      phone: '+33600000000',
      email: email,
    ),
  );
  @override
  Future<void> logout() async {}
  @override
  Future<void> clearSession() async {}
}

class _Tokens extends Fake implements TokenRepository {
  String? access = 'previous-customer';
  String? refresh = 'previous-refresh';
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String token) async {
    access = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refresh = token;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }
}

class _Fcm extends Fake implements FcmService {
  @override
  Future<void> registerWithBackend() async {}
}

AuthResponse response(String email) => AuthResponse(
  user: User(id: 'app-$email', email: email, phoneNumber: '+33600000000'),
  accessToken: email,
  refreshToken: 'refresh-$email',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _AppAuth app;
  late _Tokens tokens;
  late ProviderContainer container;
  setUp(() {
    app = _AppAuth();
    tokens = _Tokens();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(app),
        tokenRepositoryProvider.overrideWithValue(tokens),
        reservationAuthRepositoryProvider.overrideWithValue(_ReservationAuth()),
        fcmServiceProvider.overrideWithValue(_Fcm()),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'a rejected registration cannot delete the previously signed-in customer',
    () async {
      await container
          .read(authStateProvider.notifier)
          .register(
            email: 'existing@example.test',
            phoneNumber: '+33600000000',
            password: 'test-only',
            firstName: 'Test',
            lastName: 'Client',
          );
      expect(app.deletes, 0);
      expect(tokens.access, isNull);
      expect(container.read(authStateProvider).status, AuthStatus.error);
    },
  );

  test(
    'new reservation login clears the previous customer app token before it is exposed',
    () async {
      await container
          .read(authStateProvider.notifier)
          .login(email: 'new@example.test', password: 'test-only');
      expect(tokens.access, isNull);
      expect(container.read(authStateProvider).user!.email, 'new@example.test');
      app.responses['new@example.test']!.complete(response('new@example.test'));
      await Future<void>.delayed(Duration.zero);
      expect(tokens.access, 'new@example.test');
    },
  );

  test('delayed app login cannot restore a session after logout', () async {
    final controller = container.read(authStateProvider.notifier);
    await controller.login(email: 'old@example.test', password: 'test-only');
    await controller.logout();
    app.responses['old@example.test']!.complete(response('old@example.test'));
    await Future<void>.delayed(Duration.zero);
    expect(tokens.access, isNull);
    expect(tokens.refresh, isNull);
    expect(
      container.read(authStateProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test(
    'an earlier login response cannot replace the latest customer',
    () async {
      final controller = container.read(authStateProvider.notifier);
      await controller.login(email: 'old@example.test', password: 'test-only');
      await controller.login(email: 'new@example.test', password: 'test-only');
      app.responses['new@example.test']!.complete(response('new@example.test'));
      await Future<void>.delayed(Duration.zero);
      app.responses['old@example.test']!.complete(response('old@example.test'));
      await Future<void>.delayed(Duration.zero);
      expect(tokens.access, 'new@example.test');
      expect(
        container.read(authStateProvider).user!.id,
        'app-new@example.test',
      );
    },
  );
}
