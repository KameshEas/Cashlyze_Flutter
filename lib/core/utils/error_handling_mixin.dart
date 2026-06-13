import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_exception.dart';
import 'error_handler.dart';

/// Mixin for standardized error handling in repositories and services
mixin ErrorHandlingMixin {
  /// Execute a function and handle errors consistently
  Future<T> executeWithErrorHandling<T>(
    final Future<T> Function() operation, {
    final String? context,
    final Map<String, dynamic>? extraData,
  }) async {
    try {
      return await operation();
    } on DioException catch (e) {
      final apiException = errorHandler.mapDioException(e);
      await errorHandler.handleException(
        apiException,
        stackTrace: StackTrace.current,
        context: context,
        extraData: extraData,
      );
      rethrow;
    } on ApiException catch (e) {
      await errorHandler.handleException(
        e,
        stackTrace: StackTrace.current,
        context: context,
        extraData: extraData,
      );
      rethrow;
    } catch (e) {
      await errorHandler.handleException(
        e,
        stackTrace: StackTrace.current,
        context: context,
        extraData: extraData,
      );
      rethrow;
    }
  }

  /// Execute with retry logic
  Future<T> executeWithRetry<T>(
    final Future<T> Function() operation, {
    final int maxRetries = 3,
    final Duration initialDelay = const Duration(milliseconds: 100),
    final String? context,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries || !errorHandler.isRetryable(e)) {
          await errorHandler.handleException(
            e,
            stackTrace: StackTrace.current,
            context: context,
            extraData: {'attempt': attempt, 'max_retries': maxRetries},
          );
          rethrow;
        }

        // Exponential backoff
        final delay = initialDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
  }

  /// Log operation progress
  void logProgress(final String message, final Map<String, dynamic>? data) {
    errorHandler.logBreadcrumb(
      message: message,
      level: SentryLevel.info,
      data: data,
    );
  }
}
