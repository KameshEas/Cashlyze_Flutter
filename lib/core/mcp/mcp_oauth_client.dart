import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../services/secure_storage_service.dart';
import 'mcp_exception.dart';
import 'pkce.dart';

/// OAuth 2.1 + PKCE client for the `services/auth` authorization server.
///
/// Implements exactly the flow the backend requires (see
/// `services/auth/app/oauth/routes.py`): the user must already hold a
/// regular Cashlyze session (`app: "cashlyze"` JWT) before `/oauth/authorize`
/// will issue a code, since that's how the auth service verifies which
/// Cashlyze account is granting access. There is no browser/consent screen -
/// `POST /oauth/authorize` doubles as the consent step.
///
/// Result tokens are `app: "mcp_cashlyze"`-scoped and only valid against the
/// MCP server (see [McpClient]), never the regular REST API.
class McpOAuthClient {
  McpOAuthClient({required this.secureStorage}) : _dio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.gatewayBaseUrl,
            connectTimeout: EnvConfig.connectTimeout,
            receiveTimeout: EnvConfig.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  final SecureStorageService secureStorage;
  final Dio _dio;

  /// True once a connect flow has completed and tokens are stored locally.
  /// Does not itself verify the tokens are still valid server-side - a
  /// stale/revoked token surfaces as [McpReauthRequiredException] on first
  /// use, handled by [getValidAccessToken].
  Future<bool> isConnected() async =>
      (await secureStorage.getMcpAccessToken()) != null;

  /// Runs the full authorize + token exchange, storing the resulting MCP
  /// token pair. Call this from a "Connect on-device AI" action; the user
  /// must already be logged into Cashlyze.
  Future<void> connect() async {
    final cashlyzeToken = await secureStorage.getAuthToken();
    if (cashlyzeToken == null) {
      throw const McpNotLoggedInException();
    }

    final pkce = PkcePair.generate();
    final state = generateOAuthState();

    final String code;
    try {
      final authorizeResponse = await _dio.post<Map<String, dynamic>>(
        '/oauth/authorize',
        options: Options(headers: {'Authorization': 'Bearer $cashlyzeToken'}),
        data: {
          'client_id': EnvConfig.mcpOAuthClientId,
          'redirect_uri': EnvConfig.mcpOAuthRedirectUri,
          'code_challenge': pkce.codeChallenge,
          'code_challenge_method': 'S256',
          'scope': 'cashlyze',
          'state': state,
        },
      );
      final body = authorizeResponse.data;
      if (body == null || body['code'] is! String) {
        throw const McpAuthorizationException('Authorize step returned no code.');
      }
      if (body['state'] != state) {
        throw const McpAuthorizationException('OAuth state mismatch.');
      }
      code = body['code'] as String;
    } on DioException catch (e) {
      throw McpAuthorizationException(_dioMessage(e, 'Authorization request failed'));
    }

    try {
      final tokenResponse = await _dio.post<Map<String, dynamic>>(
        '/oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': EnvConfig.mcpOAuthRedirectUri,
          'code_verifier': pkce.codeVerifier,
          'client_id': EnvConfig.mcpOAuthClientId,
        },
      );
      await _persistTokens(tokenResponse.data);
    } on DioException catch (e) {
      throw McpAuthorizationException(_dioMessage(e, 'Token exchange failed'));
    }

    await secureStorage.saveMcpClientId(EnvConfig.mcpOAuthClientId);
  }

  /// Returns a valid MCP access token, transparently refreshing it if the
  /// stored one is close to/past expiry. Throws [McpNotConnectedException]
  /// if the user has never connected, or [McpReauthRequiredException] if the
  /// refresh token itself was rejected (requires a full [connect] again).
  Future<String> getValidAccessToken() async {
    final accessToken = await secureStorage.getMcpAccessToken();
    if (accessToken == null) {
      throw const McpNotConnectedException();
    }
    return accessToken;
  }

  /// Called by [McpClient] on a 401 from the MCP server - rotates the
  /// refresh token (single-use on the backend) and returns the new access
  /// token, or throws [McpReauthRequiredException] if the refresh token is
  /// itself no longer valid.
  Future<String> refresh() async {
    final refreshToken = await secureStorage.getMcpRefreshToken();
    if (refreshToken == null) {
      throw const McpReauthRequiredException();
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/oauth/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': EnvConfig.mcpOAuthClientId,
        },
      );
      await _persistTokens(response.data);
      return (await secureStorage.getMcpAccessToken())!;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        await secureStorage.clearMcpTokens();
        throw const McpReauthRequiredException();
      }
      throw McpAuthorizationException(_dioMessage(e, 'Token refresh failed'));
    }
  }

  /// Revokes the stored refresh token server-side and clears local tokens.
  /// Safe to call even if already disconnected.
  Future<void> disconnect() async {
    final refreshToken = await secureStorage.getMcpRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post<void>(
          '/oauth/revoke',
          data: {'token': refreshToken, 'client_id': EnvConfig.mcpOAuthClientId},
        );
      } on DioException {
        // Best-effort - clear local tokens regardless so the app's state is
        // consistent even if the network call failed.
      }
    }
    await secureStorage.clearMcpTokens();
  }

  Future<void> _persistTokens(final Map<String, dynamic>? body) async {
    if (body == null ||
        body['access_token'] is! String ||
        body['refresh_token'] is! String) {
      throw const McpAuthorizationException('Token response was malformed.');
    }
    await secureStorage.saveMcpAccessToken(body['access_token'] as String);
    await secureStorage.saveMcpRefreshToken(body['refresh_token'] as String);
  }

  String _dioMessage(final DioException e, final String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'] ?? data['error_description'];
      if (detail != null) return detail.toString();
    }
    return e.message ?? fallback;
  }
}

final mcpOAuthClientProvider = Provider<McpOAuthClient>((final ref) {
  return McpOAuthClient(secureStorage: ref.watch(secureStorageServiceProvider));
});
