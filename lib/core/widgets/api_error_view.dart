import 'package:flutter/material.dart';

import '../api/api_exception.dart';

/// Returns a user-facing message string for any [ApiException].
///
/// Keeps error presentation consistent across the app without coupling
/// individual screens to exception implementation details.
String apiErrorMessage(ApiException e) {
  return switch (e) {
    ValidationException() => e.message,
    UnauthorizedException() =>
      'Your session has expired. Please sign in again.',
    ForbiddenException() =>
      'You don\'t have permission to perform this action.',
    NotFoundException() => 'The requested item could not be found.',
    ConflictException() => e.message,
    ServerException() =>
      'Something went wrong on our end. Please try again later.',
    TimeoutException() =>
      'The request timed out. Check your connection and try again.',
    NetworkException() =>
      'No internet connection. Please check your network.',
    TokenRefreshException() => e.message,
    ParseException() => 'Received an unexpected response. Please try again.',
    UnknownApiException() => 'An unexpected error occurred. Please try again.',
  };
}

/// A compact error display widget for inline API errors.
///
/// Usage:
/// ```dart
/// if (error != null) ApiErrorView(error: error!)
/// ```
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  final ApiException error;

  /// Optional retry callback. When supplied, a "Retry" button is shown.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNetwork = error is NetworkException || error is TimeoutException;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  apiErrorMessage(error),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows an [ApiException] as a [SnackBar].
///
/// Call from a [BuildContext] that has a [ScaffoldMessenger] ancestor.
void showApiErrorSnackBar(
  BuildContext context,
  ApiException error, {
  VoidCallback? onRetry,
}) {
  final message = apiErrorMessage(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: onRetry,
            )
          : null,
    ),
  );
}
