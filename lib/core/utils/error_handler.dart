import 'dart:io';
import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_exception.dart';

/// Standard error handler that provides consistent error handling and recovery
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._();

  factory ErrorHandler() => _instance;

  ErrorHandler._();

  /// Convert Dio exception to typed ApiException
  ApiException mapDioException(final DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode != null) {
      return switch (statusCode) {
        400 => ValidationException(
            error.message ?? 'Validation failed',
            errors: error.response?.data is Map
                ? (error.response?.data as Map)['errors'] as Map<String, dynamic>?
                : null,
          ),
        401 => UnauthorizedException(error.message ?? 'Unauthorized'),
        403 => ForbiddenException(error.message ?? 'Forbidden'),
        404 => NotFoundException(error.message ?? 'Not found'),
        409 => ConflictException(error.message ?? 'Conflict'),
        >= 500 => ServerException.withStatus(statusCode),
        _ => _mapNetworkError(error),
      };
    }

    return _mapNetworkError(error);
  }

  ApiException _mapNetworkError(final DioException error) {
    return switch (error.type) {
      DioExceptionType.receiveTimeout => TimeoutException(error.message ?? 'Request timed out'),
      DioExceptionType.sendTimeout => TimeoutException(error.message ?? 'Request timed out'),
      DioExceptionType.connectionTimeout => TimeoutException(error.message ?? 'Connection timed out'),
      DioExceptionType.connectionError => NetworkException(error.message ?? 'Connection failed'),
      DioExceptionType.unknown when error.error is SocketException =>
        NetworkException('Network error: ${error.message}'),
      _ => UnknownApiException(error.message ?? 'Unknown error'),
    };
  }

  /// Handle and log an exception to Sentry
  Future<void> handleException(
    final Object error, {
    final StackTrace? stackTrace,
    final String? context,
    final Map<String, dynamic>? extraData,
  }) async {
    try {
      final eventId = await Sentry.captureException(
        error,
        stackTrace: stackTrace,
      );

      if (context != null || extraData != null) {
        await Sentry.configureScope((final scope) {
          if (context != null) {
            scope.setExtra('error_context', context);
          }
          if (extraData != null) {
            extraData.forEach((final key, final value) {
              scope.setExtra(key, value);
            });
          }
        });
      }
    } catch (_) {
      // Silent fail if Sentry capture fails
    }
  }

  /// Log a breadcrumb for debugging
  void logBreadcrumb({
    required final String message,
    required final SentryLevel level,
    final Map<String, dynamic>? data,
  }) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          level: level,
          data: data,
          timestamp: DateTime.now(),
        ),
      );
    } catch (_) {
      // Silent fail
    }
  }

  /// Get user-friendly error message
  String getUserMessage(final Object error) {
    return switch (error) {
      ValidationException _ => 'Please check your input and try again',
      UnauthorizedException _ => 'Your session has expired. Please log in again.',
      ForbiddenException _ => 'You do not have permission to perform this action.',
      NotFoundException _ => 'The requested resource was not found.',
      ConflictException _ => 'This resource already exists. Please try a different value.',
      ServerException _ => 'Server error. Please try again later.',
      TimeoutException _ => 'The request took too long. Please check your connection and try again.',
      NetworkException _ => 'No internet connection. Please check your network and try again.',
      TokenRefreshException _ => 'Your session has expired. Please log in again.',
      ParseException _ => 'Failed to process the response. Please try again.',
      UnknownApiException _ => 'An unexpected error occurred. Please try again.',
      SocketException _ => 'Network connection error. Please check your connection.',
      DioException _ => 'Network error. Please try again.',
      _ => 'An unexpected error occurred. Please try again.',
    };
  }

  /// Determine if error is retryable
  bool isRetryable(final Object error) {
    return switch (error) {
      TimeoutException _ => true,
      NetworkException _ => true,
      ServerException _ => true,
      SocketException _ => true,
      DioException(:final type) => switch (type) {
          DioExceptionType.receiveTimeout => true,
          DioExceptionType.sendTimeout => true,
          DioExceptionType.connectionTimeout => true,
          DioExceptionType.connectionError => true,
          _ => false,
        },
      _ => false,
    };
  }
}

/// Global error handler instance
final errorHandler = ErrorHandler();
