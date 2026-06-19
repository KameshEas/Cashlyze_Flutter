import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/secure_storage_service.dart';
import 'api_endpoints.dart';

/// Dio interceptor that:
/// 1. Attaches the stored Bearer access token to every outgoing request.
/// 2. On a 401 response, attempts a silent token refresh once, retries the
///    original request with the new token, and forces a logout if the refresh
///    also fails.
///
/// Only one refresh call is ever in-flight at a time; subsequent 401s wait
/// for the same future via [_refreshLock].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.onForceLogout,
  });

  final SecureStorageService secureStorage;

  /// Called when the refresh fails – the app should clear session state and
  /// navigate to the login screen.
  final void Function() onForceLogout;

  // Single-flight lock: ensures parallel requests don't each kick off their
  // own refresh.
  Future<String?>? _refreshLock;

  @override
  Future<void> onRequest(
    final RequestOptions options,
    final RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.getAuthToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    final DioException err,
    final ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Avoid refresh loops: if this request itself is the refresh endpoint,
    // propagate the failure immediately.
    if (err.requestOptions.path.contains(ApiEndpoints.refresh)) {
      _refreshLock = null;
      onForceLogout();
      handler.reject(err);
      return;
    }

    try {
      final newToken = await _getOrRunRefresh(err.requestOptions.extra['dio'] as Dio?);
      if (newToken == null) {
        onForceLogout();
        handler.reject(err);
        return;
      }

      // Retry the original request with the new token.
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken';
      final dio = err.requestOptions.extra['dio'] as Dio?;
      if (dio == null) {
        handler.reject(err);
        return;
      }
      final retryResponse = await dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      onForceLogout();
      handler.reject(err);
    }
  }

  /// Runs a single token refresh and caches the in-flight future so parallel
  /// requests share the result.
  Future<String?> _getOrRunRefresh(final Dio? dio) {
    _refreshLock ??= _runRefresh(dio).whenComplete(() => _refreshLock = null);
    return _refreshLock!;
  }

  Future<String?> _runRefresh(final Dio? dio) async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || dio == null) return null;

    try {
      final resp = await dio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
        options: Options(
          // Skip the auth interceptor for this call.
          extra: {'skipAuthInterceptor': true},
        ),
      );
      final body = resp.data as Map<String, dynamic>?;
      final newAccess = body?['access_token'] as String?;
      final newRefresh = body?['refresh_token'] as String?;
      if (newAccess == null) return null;

      await secureStorage.saveAuthToken(newAccess);
      if (newRefresh != null) {
        await secureStorage.saveRefreshToken(newRefresh);
      }
      return newAccess;
    } catch (_) {
      return null;
    }
  }
}

/// Provider for [AuthInterceptor].
///
/// Consumers must supply a [onForceLogout] callback when constructing the
/// interceptor; this provider supplies a no-op version that is replaced at
/// the [ApiClient] layer with the real logout handler.
final authInterceptorProvider = Provider<AuthInterceptor>((final ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthInterceptor(
    secureStorage: storage,
    onForceLogout: () {},
  );
});
