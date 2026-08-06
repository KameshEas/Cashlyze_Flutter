import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../services/auth_session_events.dart';
import '../services/secure_storage_service.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

/// Central HTTP client for the Cashlyze backend API.
///
/// Wraps [Dio] with:
/// - Bearer-token attachment via [AuthInterceptor]
/// - Silent token refresh on 401 responses
/// - Retry on transient network errors via [RetryInterceptor]
/// - Request/response logging in debug builds
/// - Typed error mapping ([ApiException] subtypes)
class ApiClient {
  factory ApiClient.create({
    required final SecureStorageService secureStorage,
    required final void Function() onForceLogout,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: EnvConfig.connectTimeout,
        receiveTimeout: EnvConfig.receiveTimeout,
        sendTimeout: EnvConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Expose the Dio instance in request extras so interceptors can use it.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (final options, final handler) {
          options.extra['dio'] = dio;
          handler.next(options);
        },
      ),
    );

    // Token attachment + silent refresh.
    dio.interceptors.add(
      AuthInterceptor(
        secureStorage: secureStorage,
        onForceLogout: onForceLogout,
      ),
    );

    // Retry safe methods on transient errors.
    dio.interceptors.add(RetryInterceptor());

    // Logging (debug only – never logs tokens in release builds).
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false, // avoid leaking auth headers in debug logs
          responseHeader: false,
          logPrint: (final obj) => debugApiLog(obj.toString()),
        ),
      );
    }

    return ApiClient._(dio: dio);
  }

  ApiClient._({required final Dio dio}) : _dio = dio;

  final Dio _dio;

  // ── Public HTTP helpers ───────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    final String path, {
    final Map<String, dynamic>? queryParameters,
    final Options? options,
  }) =>
      _execute(() => _dio.get<T>(
            path,
            queryParameters: queryParameters,
            options: options,
          ));

  Future<Response<T>> post<T>(
    final String path, {
    final dynamic data,
    final Map<String, dynamic>? queryParameters,
    final Options? options,
  }) =>
      _execute(() => _dio.post<T>(
            path,
            data: data,
            queryParameters: queryParameters,
            options: options,
          ));

  Future<Response<T>> put<T>(
    final String path, {
    final dynamic data,
    final Options? options,
  }) =>
      _execute(() => _dio.put<T>(path, data: data, options: options));

  Future<Response<T>> patch<T>(
    final String path, {
    final dynamic data,
    final Options? options,
  }) =>
      _execute(() => _dio.patch<T>(path, data: data, options: options));

  Future<Response<T>> delete<T>(
    final String path, {
    final dynamic data,
    final Options? options,
  }) =>
      _execute(() => _dio.delete<T>(path, data: data, options: options));

  // ── Error mapping ─────────────────────────────────────────────────────────

  Future<Response<T>> _execute<T>(final Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnknownApiException(e.toString());
    }
  }

  ApiException _mapDioException(final DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        if (e.error is SocketException) return const NetworkException();
        return NetworkException(e.message ?? 'Connection error');
      case DioExceptionType.badResponse:
        return _mapHttpStatus(e.response);
      case DioExceptionType.cancel:
        return const UnknownApiException('Request cancelled');
      default:
        if (e.error is SocketException) return const NetworkException();
        return UnknownApiException(e.message ?? 'Unknown error');
    }
  }

  ApiException _mapHttpStatus(final Response<dynamic>? response) {
    final statusCode = response?.statusCode ?? 0;
    final data = response?.data;
    final message = _extractMessage(data);

    return switch (statusCode) {
      400 => ValidationException(
          message ?? 'Validation error',
          errors: data is Map<String, dynamic> ? data['errors'] as Map<String, dynamic>? : null,
        ),
      401 => UnauthorizedException(message ?? 'Unauthorized'),
      403 => ForbiddenException(message ?? 'Forbidden'),
      404 => NotFoundException(message ?? 'Not found'),
      409 => ConflictException(message ?? 'Conflict'),
      429 => TooManyRequestsException(message ?? 'Too many requests. Please try again later.'),
      _ when statusCode >= 500 => ServerException.withStatus(statusCode, message),
      _ => UnknownApiException('HTTP $statusCode: ${message ?? 'Unknown'}'),
    };
  }

  String? _extractMessage(final dynamic data) {
    if (data is Map<String, dynamic>) {
      return (data['message'] ?? data['detail'] ?? data['error'])?.toString();
    }
    return null;
  }
}

// ── Logging helper ────────────────────────────────────────────────────────────

/// Override to redirect API debug logs to your preferred sink (e.g. Sentry
/// breadcrumbs, custom logger).  Defaults to [print].
void debugApiLog(final String message) {
  // ignore: avoid_print
  print('[ApiClient] $message');
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provider for [ApiClient].
///
/// On a permanent 401 (token refresh failure), calls [AuthService.signOut]
/// and clears locally stored tokens so the router guard redirects to login.
final apiClientProvider = Provider<ApiClient>((final ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ApiClient.create(
    secureStorage: storage,
    onForceLogout: () async {
      await storage.deleteAuthToken();
      await storage.deleteRefreshToken();
      // Notify AuthService via the dependency-free event bus (see
      // auth_session_events.dart) rather than depending on authServiceProvider
      // directly, which would create a provider cycle.
      forcedLogoutEvents.add(null);
    },
  );
});
