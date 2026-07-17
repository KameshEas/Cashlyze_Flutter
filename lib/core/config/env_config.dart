/// Environment configuration for the Cashlyze API.
///
/// Toggle [useLocalhostForTesting] to point the app at a local backend
/// during development. The flag should always be `false` in production builds.
abstract final class EnvConfig {
  /// Set to `true` only during local backend development.
  /// Must be `false` for production / CI / release builds.
  static const bool useLocalhostForTesting = true;

  static const String _productionBaseUrl =
      'https://api.aspired2d.cloud/api/v1/cashlyze';

  /// Change to your local address as needed (e.g. `http://10.0.2.2:8000`
  /// for the Android emulator, or your machine's LAN IP for a physical device).
  static const String _localhostBaseUrl =
      'http://192.168.0.6:8000/api/v1/cashlyze';

  /// The resolved base URL used by [ApiClient].
  static String get baseUrl =>
      useLocalhostForTesting ? _localhostBaseUrl : _productionBaseUrl;

  // ── Timeouts ──────────────────────────────────────────────────────────────

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
