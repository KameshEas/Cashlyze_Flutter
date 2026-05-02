import 'dart:io';

import 'package:dio/dio.dart';

/// Dio interceptor that retries idempotent requests on transient network
/// failures (socket errors, connection resets, timeouts).
///
/// Only GET / HEAD / OPTIONS requests are retried automatically; mutating
/// methods (POST, PUT, PATCH, DELETE) are not retried to avoid duplicate
/// side-effects.
///
/// Back-off strategy: exponential with a base of 1 s and a cap of 8 s.
///
/// ```
/// Attempt 1 – immediate
/// Attempt 2 – 1 s delay
/// Attempt 3 – 2 s delay
/// ```
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxRetries = 2});

  final int maxRetries;

  static const _retryCountKey = '_retryCount';
  static const _safeMethodsKey = {'GET', 'HEAD', 'OPTIONS'};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();

    // Only retry safe (idempotent) HTTP methods.
    if (!_safeMethodsKey.contains(method)) {
      handler.next(err);
      return;
    }

    // Only retry on connection-level failures, not HTTP error responses.
    if (!_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final retryCount = (options.extra[_retryCountKey] as int?) ?? 0;
    if (retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    // Exponential back-off: 0, 1, 2 seconds.
    final delay = retryCount == 0
        ? Duration.zero
        : Duration(seconds: 1 << (retryCount - 1));
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    options.extra[_retryCountKey] = retryCount + 1;

    try {
      final dio = options.extra['dio'] as Dio?;
      if (dio == null) {
        handler.next(err);
        return;
      }
      final response = await dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  bool _isRetryable(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.error is SocketException);
  }
}
