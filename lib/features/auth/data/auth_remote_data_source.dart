import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/services/secure_storage_service.dart';

// ── Response models ───────────────────────────────────────────────────────────

/// Tokens returned by login / register / refresh.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(final Map<String, dynamic> json) {
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw const ParseException('Missing tokens in auth response');
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  final String accessToken;
  final String refreshToken;
}

// ── Data source ───────────────────────────────────────────────────────────────

/// Remote data source for authentication endpoints:
/// - `POST /auth/register`
/// - `POST /auth/login`
/// - `POST /auth/refresh`
class AuthRemoteDataSource {
  const AuthRemoteDataSource({
    required final ApiClient apiClient,
    required final SecureStorageService secureStorage,
  })  : _api = apiClient,
        _storage = secureStorage;

  final ApiClient _api;
  final SecureStorageService _storage;

  // ── Register ───────────────────────────────────────────────────────────────

  /// Registers a new user after OTP verification.
  ///
  /// On success, may persist [AuthTokens] when the backend returns them.
  ///
  /// Some deployments return only a user profile object for register; in that
  /// case this returns `null` and callers should navigate to login.
  Future<AuthTokens?> register({
    required final String email,
    required final String password,
    final String? otpToken,
    final String? name,
    final String? mobile,
    final String? displayName,
    final String? photoUrl,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        if (otpToken != null && otpToken.isNotEmpty) 'otp_token': otpToken,
        if (name != null) 'name': name,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        if (displayName != null) 'display_name': displayName,
        if (photoUrl != null) 'photo_url': photoUrl,
      },
    );
    final body = (response.data as Map).cast<String, dynamic>();
    final access = body['access_token'] as String?;
    final refresh = body['refresh_token'] as String?;
    if (access != null && refresh != null) {
      final tokens = AuthTokens(accessToken: access, refreshToken: refresh);
      await _persistTokens(tokens);
      return tokens;
    }
    return null;
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  /// Logs in with email + password.
  ///
  /// The backend may require OTP verification before the first login; in that
  /// case a [ForbiddenException] is thrown and the caller should redirect to
  /// the OTP screen.
  ///
  /// On success, persists [AuthTokens] to secure storage.
  Future<AuthTokens> login({
    required final String email,
    required final String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      queryParameters: {'email': email, 'password': password},
    );
    final tokens = AuthTokens.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
    await _persistTokens(tokens);
    return tokens;
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  /// Silently refreshes the access token using the stored refresh token.
  ///
  /// Returns new [AuthTokens] and persists them.
  /// Throws [TokenRefreshException] if no refresh token is stored or the
  /// backend rejects it.
  Future<AuthTokens> refreshTokens() async {
    final storedRefresh = await _storage.getRefreshToken();
    if (storedRefresh == null) {
      throw const TokenRefreshException();
    }

    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.refresh,
      data: {'refresh_token': storedRefresh},
    );
    final tokens = AuthTokens.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
    await _persistTokens(tokens);
    return tokens;
  }

  // ── Logout (local) ─────────────────────────────────────────────────────────

  /// Clears all locally stored auth tokens.
  Future<void> clearTokens() async {
    await _storage.deleteAuthToken();
    await _storage.deleteRefreshToken();
  }

  // ── Change password ────────────────────────────────────────────────────────

  /// Changes the authenticated user's password.
  Future<void> changePassword({
    required final String currentPassword,
    required final String newPassword,
  }) async {
    await _api.patch<void>(
      ApiEndpoints.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  // ── Delete account ─────────────────────────────────────────────────────────

  /// Permanently deletes the authenticated user's account.
  Future<void> deleteAccount() async {
    await _api.delete<void>(ApiEndpoints.usersMe);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _persistTokens(final AuthTokens tokens) async {
    await _storage.saveAuthToken(tokens.accessToken);
    await _storage.saveRefreshToken(tokens.refreshToken);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((final ref) {
  return AuthRemoteDataSource(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
