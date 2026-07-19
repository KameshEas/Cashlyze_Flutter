import 'package:flutter/foundation.dart' show kReleaseMode;

/// Environment configuration for the Cashlyze API.
///
/// Toggle [_useLocalhostDuringDev] to point the app at a local backend
/// during development. Release builds always force production, so
/// forgetting to flip this back before shipping is no longer possible.
abstract final class EnvConfig {
  /// Set to `true` only during local backend development.
  /// Ignored (forced `false`) in release builds — see [useLocalhostForTesting].
  static const bool _useLocalhostDuringDev = false;

  /// Resolved localhost flag: forced `false` outside of debug/profile builds,
  /// regardless of [_useLocalhostDuringDev].
  static const bool useLocalhostForTesting =
      !kReleaseMode && _useLocalhostDuringDev;

  static const String _productionBaseUrl =
      'https://api.aspired2d.cloud/api/v1/cashlyze';

  /// Change to your local address as needed (e.g. `http://10.0.2.2:8000`
  /// for the Android emulator, or your machine's LAN IP for a physical device).
  static const String _localhostBaseUrl =
      'http://192.168.0.6:8000/api/v1/cashlyze';

  /// The resolved base URL used by [ApiClient].
  static String get baseUrl =>
      useLocalhostForTesting ? _localhostBaseUrl : _productionBaseUrl;

  /// The gateway's own root (no `/api/v1/cashlyze` suffix) - OAuth discovery
  /// (`/.well-known/...`) and the `/oauth/*` endpoints live here, not under
  /// the cashlyze REST prefix. Derived from [baseUrl] so local/prod stay in
  /// sync automatically.
  static String get gatewayBaseUrl =>
      baseUrl.substring(0, baseUrl.length - '/api/v1/cashlyze'.length);

  /// The Cashlyze MCP server's Streamable HTTP endpoint.
  static String get mcpServerUrl => '$gatewayBaseUrl/mcp/cashlyze/';

  /// This app's registered OAuth client_id for the on-device AI / MCP flow.
  /// Set after running services/auth/scripts/seed_oauth_client.py once
  /// against production and pasting the printed client_id here.
  static const String mcpOAuthClientId = 'mcp-client-e07f41e473f9e246';

  /// Custom URI scheme redirect used to complete the PKCE authorize step.
  /// Must exactly match a `redirect_uris` entry on the registered OAuth
  /// client (see seed_oauth_client.py usage above).
  static const String mcpOAuthRedirectUri = 'cashlyze://oauth/callback';

  // ── Timeouts ──────────────────────────────────────────────────────────────

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
