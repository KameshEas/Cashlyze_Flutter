/// Typed API exceptions for the Cashlyze backend.
///
/// All errors surfaced from [ApiClient] are one of these subtypes so that
/// UI / repository layers can pattern-match cleanly without coupling to
/// Dio internals.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

// ── HTTP status-based errors ─────────────────────────────────────────────────

/// 400 – Request body / query parameter validation failed.
final class ValidationException extends ApiException {
  const ValidationException(super.message, {this.errors});

  /// Field-level error map returned by the backend, e.g.
  /// `{"email": ["Invalid email format"]}`.
  final Map<String, dynamic>? errors;
}

/// 401 – Access token is missing, expired, or invalid.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

/// 403 – Server understood the request but refuses to authorise it.
///
/// Common causes: OTP verification required, inactive account.
final class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Forbidden']);
}

/// 404 – Requested resource does not exist.
final class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Not found']);
}

/// 409 – Conflict; resource already exists (e.g. duplicate email).
final class ConflictException extends ApiException {
  const ConflictException([super.message = 'Conflict']);
}

/// 429 – Client has been rate-limited (e.g. too many login attempts).
final class TooManyRequestsException extends ApiException {
  const TooManyRequestsException([super.message = 'Too many requests. Please try again later.']);
}

/// 5xx – Backend returned a server error.
final class ServerException extends ApiException {
  const ServerException([super.message = 'Server error']);

  factory ServerException.withStatus(final int statusCode, [final String? detail]) =>
      ServerException(detail ?? 'Server error ($statusCode)');
}

// ── Network / transport errors ────────────────────────────────────────────────

/// Request timed out before a response was received.
final class TimeoutException extends ApiException {
  const TimeoutException([super.message = 'Request timed out']);
}

/// Device has no network connectivity or the host is unreachable.
final class NetworkException extends ApiException {
  const NetworkException([super.message = 'No network connection']);
}

/// The token refresh flow failed – the caller should force a logout.
final class TokenRefreshException extends ApiException {
  const TokenRefreshException([super.message = 'Session expired. Please log in again.']);
}

/// A response was received but could not be parsed into the expected model.
final class ParseException extends ApiException {
  const ParseException(super.message);
}

/// Catch-all for any unexpected API error.
final class UnknownApiException extends ApiException {
  const UnknownApiException([super.message = 'An unexpected error occurred']);
}
