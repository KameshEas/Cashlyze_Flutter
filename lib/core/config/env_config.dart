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

  // ── Timeouts ──────────────────────────────────────────────────────────────

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
