import 'package:barber/core/network/dio_client.dart';
import 'package:barber/core/storage/token_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tokens extends Fake implements TokenRepository {
  String? access = 'old-access';
  String? refresh = 'old-refresh';
  int clears = 0;
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String value) async {
    access = value;
  }

  @override
  Future<void> saveRefreshToken(String value) async {
    refresh = value;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
    clears++;
  }
}

void reject(
  RequestOptions request,
  RequestInterceptorHandler handler,
  int status,
) {
  handler.reject(
    DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: request, statusCode: status, data: {}),
    ),
    true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in ['/api/v1/auth/login', '/api/v1/auth/logout']) {
    test('401 on $path does not refresh or attach an old session', () async {
      final tokens = _Tokens();
      final client = DioClient(tokenRepository: tokens, dio: Dio());
      var count = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            count++;
            expect(r.headers['Authorization'], isNull);
            reject(r, h, 401);
          },
        ),
      );
      await expectLater(
        client.dio.post<dynamic>(path),
        throwsA(isA<DioException>()),
      );
      expect(count, 1);
      expect(tokens.clears, 0);
    });
  }

  test(
    'permanent resource 401 has one refresh and one retry, never a loop',
    () async {
      final tokens = _Tokens();
      final client = DioClient(tokenRepository: tokens, dio: Dio());
      var refreshes = 0;
      var reads = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.path.endsWith('/refresh')) {
              refreshes++;
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-access',
                    'refreshToken': 'new-refresh',
                  },
                ),
              );
            } else {
              reads++;
              reject(r, h, 401);
            }
          },
        ),
      );
      await expectLater(
        client.dio
            .get<dynamic>('/api/v1/auth/me')
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );
      expect(refreshes, 1);
      expect(reads, 2);
    },
  );

  test('concurrent protected requests share one refresh', () async {
    final tokens = _Tokens();
    final client = DioClient(tokenRepository: tokens, dio: Dio());
    var refreshes = 0;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          if (r.path.endsWith('/refresh')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                },
              ),
            );
          } else if (r.headers['Authorization'] == 'Bearer new-access') {
            h.resolve(Response(requestOptions: r, statusCode: 200, data: {}));
          } else {
            reject(r, h, 401);
          }
        },
      ),
    );
    final responses = await Future.wait([
      client.dio.get<dynamic>('/api/v1/auth/me'),
      client.dio.get<dynamic>('/api/v1/loyalty/me'),
    ]);
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshes, 1);
  });

  for (final status in [401, 503]) {
    test(
      'refresh $status only clears tokens for a definitive rejection',
      () async {
        final tokens = _Tokens();
        final client = DioClient(tokenRepository: tokens, dio: Dio());
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              reject(r, h, r.path.endsWith('/refresh') ? status : 401);
            },
          ),
        );
        await expectLater(
          client.dio.get<dynamic>('/api/v1/auth/me'),
          throwsA(isA<DioException>()),
        );
        expect(tokens.clears, status == 401 ? 1 : 0);
        if (status == 503) expect(tokens.refresh, 'old-refresh');
      },
    );
  }

  test('refresh response cannot restore a logged-out session', () async {
    final tokens = _Tokens();
    final client = DioClient(tokenRepository: tokens, dio: Dio());
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          if (r.path.endsWith('/refresh')) {
            await tokens.clearTokens();
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                },
              ),
            );
          } else {
            reject(r, h, 401);
          }
        },
      ),
    );
    await expectLater(
      client.dio.get<dynamic>('/api/v1/auth/me'),
      throwsA(isA<DioException>()),
    );
    expect(tokens.access, isNull);
    expect(tokens.refresh, isNull);
  });
}
