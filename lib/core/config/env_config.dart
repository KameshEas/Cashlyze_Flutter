import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'aspire_services_config.dart';

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
  ///
  /// Order: local-dev override, then `assets/aspire-services.json` (from
  /// Aspire Helm), then the built-in production URL.
  static String get baseUrl {
    if (useLocalhostForTesting) return _localhostBaseUrl;
    final gateway = AspireServicesConfig.apiBaseUrl;
    final app = AspireServicesConfig.appName;
    if (gateway != null && app != null) return '$gateway/api/v1/$app';
    return _productionBaseUrl;
  }

  // ── OneSignal ─────────────────────────────────────────────────────────────

  /// The same key given at build time: `flutter build --dart-define=ONESIGNAL_APP_ID=...`.
  static const String _oneSignalAppIdDefine = String.fromEnvironment('ONESIGNAL_APP_ID');

  /// The OneSignal App ID, or `null` if the build has none. There is deliberately
  /// no default: the ID is kept out of the source, so a build made without it
  /// can't use push.
  ///
  /// Order: `ONESIGNAL_APP_ID` in `.env` (which the pipeline writes from its
  /// secrets), then `--dart-define=ONESIGNAL_APP_ID`, like `SENTRY_DSN`.
  ///
  /// Safe to call even if `.env` failed to load (reading `dotenv.env` would
  /// throw), so a missing file gives `null` rather than an error nobody sees.
  static String? get oneSignalAppId {
    final fromEnv = dotenv.isInitialized ? dotenv.env['ONESIGNAL_APP_ID']?.trim() : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    final fromDefine = _oneSignalAppIdDefine.trim();
    return fromDefine.isEmpty ? null : fromDefine;
  }

  // ── Timeouts ──────────────────────────────────────────────────────────────

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
