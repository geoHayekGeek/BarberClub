import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../storage/token_repository.dart';

/// Global navigation key for refresh interceptor
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Dio client with authentication interceptors
class DioClient {
  DioClient({
    required TokenRepository tokenRepository,
    Dio? dio,
  })  : _tokenRepository = tokenRepository,
        _dio = dio ?? Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(milliseconds: AppConfig.apiTimeoutMs),
            receiveTimeout: const Duration(milliseconds: AppConfig.apiTimeoutMs),
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
  
  // Refresh token lock to prevent parallel refresh calls
  bool _isRefreshing = false;
  final List<Completer<bool>> _refreshQueue = [];

  void _setupInterceptors() {
    // Auth interceptor: attach access token to requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _tokenRepository.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors with refresh token flow
          if (error.response?.statusCode == 401) {
            final requestOptions = error.requestOptions;
            
            // Skip refresh for refresh endpoint itself
            if (requestOptions.path == AppConfig.refreshTokenPath) {
              await _tokenRepository.clearTokens();
              _navigateToLogin();
              return handler.next(error);
            }
            
            // Try to refresh token
            try {
              final refreshed = await _refreshToken();
              if (refreshed) {
                // Retry original request with new token
                final accessToken = await _tokenRepository.getAccessToken();
                if (accessToken != null) {
                  requestOptions.headers['Authorization'] = 'Bearer $accessToken';
                  final response = await _dio.fetch(requestOptions);
                  return handler.resolve(response);
                }
              }
            } catch (e) {
              // Refresh failed, clear tokens and navigate to login
              await _tokenRepository.clearTokens();
              _navigateToLogin();
              return handler.next(error);
            }
          }
          
          handler.next(error);
        },
      ),
    );
  }

  /// Refresh access token using refresh token
  Future<bool> _refreshToken() async {
    // If already refreshing, wait for the ongoing refresh
    if (_isRefreshing) {
      final completer = Completer<bool>();
      _refreshQueue.add(completer);
      return await completer.future;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenRepository.getRefreshToken();
      if (refreshToken == null) {
        _isRefreshing = false;
        _resolveQueue(false);
        return false;
      }

      final response = await _dio.post(
        AppConfig.refreshTokenPath,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await _tokenRepository.saveAccessToken(newAccessToken);
          await _tokenRepository.saveRefreshToken(newRefreshToken);
          
          _isRefreshing = false;
          _resolveQueue(true);
          return true;
        }
      }

      _isRefreshing = false;
      _resolveQueue(false);
      return false;
    } catch (e) {
      // Refresh failed
      _isRefreshing = false;
      _resolveQueue(false);
      return false;
    }
  }

  void _resolveQueue(bool success) {
    for (final completer in _refreshQueue) {
      completer.complete(success);
    }
    _refreshQueue.clear();
  }

  void _navigateToLogin() {
    // Use GoRouter if available, otherwise use Navigator
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        context.go('/login');
      } catch (e) {
        // Fallback if GoRouter not available
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Dio get dio => _dio;
}
