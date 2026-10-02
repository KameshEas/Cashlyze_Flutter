import 'dart:async';

/// Fired when a background token refresh fails and [ApiClient] force-clears
/// stored tokens, so [AuthService] can react immediately.
///
/// Deliberately dependency-free: `api_client.dart` and `auth_service.dart`
/// each import only this file, not each other, avoiding the provider cycle
/// apiClientProvider -> authRemoteDataSourceProvider -> authServiceProvider
/// -> (back to) apiClientProvider that a direct import would create.
final forcedLogoutEvents = StreamController<void>.broadcast();
