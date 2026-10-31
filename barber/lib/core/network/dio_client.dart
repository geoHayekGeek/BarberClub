import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../storage/token_repository.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App tokens never substitute for reservation tokens. Refresh at most once for
/// a protected request and share the refresh across concurrent 401 responses.
class DioClient {
  DioClient({required TokenRepository tokenRepository, Dio? dio})
    : _tokenRepository = tokenRepository,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(
                milliseconds: AppConfig.apiTimeoutMs,
              ),
              receiveTimeout: const Duration(
                milliseconds: AppConfig.apiTimeoutMs,
              ),
              sendTimeout: const Duration(milliseconds: AppConfig.apiTimeoutMs),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    _setupInterceptors();
  }

  final TokenRepository _tokenRepository;
  final Dio _dio;
  Future<bool>? _refreshInFlight;
  static const _retried = 'barberclub.authRetried';

  bool _isSessionEndpoint(String path) => const {
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    '/api/v1/auth/refresh',
    '/api/v1/auth/logout',
    '/api/v1/auth/forgot-password',
    '/api/v1/auth/reset-password',
  }.contains(Uri.parse(path).path);

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isSessionEndpoint(options.path)) {
            try {
              final access = await _tokenRepository.getAccessToken();
              if (access != null && access.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $access';
              }
            } catch (_) {
              // Public reads can still succeed while secure storage is unavailable.
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final failedAuthorization = request.headers['Authorization'];
          if (error.response?.statusCode != 401 ||
              _isSessionEndpoint(request.path) ||
              request.extra[_retried] == true ||
              failedAuthorization == null) {
            handler.next(error);
            return;
          }

          try {
            final current = await _tokenRepository.getAccessToken();
            // A different request may already have refreshed this expired token.
            final alreadyRotated =
                current != null &&
                current.isNotEmpty &&
                failedAuthorization != 'Bearer $current';
            if (alreadyRotated || await _refreshToken()) {
              final access = await _tokenRepository.getAccessToken();
              if (access != null && access.isNotEmpty) {
                request.extra[_retried] = true;
                request.headers['Authorization'] = 'Bearer $access';
                try {
                  final response = await _dio.fetch<dynamic>(request);
                  handler.resolve(response);
                } on DioException catch (retryError) {
                  // Surface the terminal failure, not another refresh loop.
                  handler.next(retryError);
                }
                return;
              }
            }
          } catch (_) {
            // Temporary network/storage failures do not invalidate credentials.
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final future = _refreshOnce();
    _refreshInFlight = future.whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  Future<bool> _refreshOnce() async {
    final refresh = await _tokenRepository.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _dio.post<dynamic>(
        AppConfig.refreshTokenPath,
        data: {'refreshToken': refresh},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return false;
      final access = data['accessToken'];
      final nextRefresh = data['refreshToken'];
      if (access is! String ||
          access.isEmpty ||
          nextRefresh is! String ||
          nextRefresh.isEmpty) {
        return false;
      }
      // Do not restore an old session after logout or a different sign-in.
      if (await _tokenRepository.getRefreshToken() != refresh) return false;
      await _tokenRepository.saveAccessToken(access);
      await _tokenRepository.saveRefreshToken(nextRefresh);
      return true;
    } on DioException catch (error) {
      if ((error.response?.statusCode == 401 ||
              error.response?.statusCode == 403) &&
          await _tokenRepository.getRefreshToken() == refresh) {
        await _tokenRepository.clearTokens();
        _navigateToLogin();
      }
      return false;
    }
  }

  void _navigateToLogin() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      context.go('/login');
    } catch (_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Dio get dio => _dio;
}
